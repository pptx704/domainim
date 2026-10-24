import std/[unittest, json, tables, strutils, os, posix, sequtils]
import ../src/[results, runner]
import ../src/modules/[iputils, subfinder]

proc okResult(domain: string, udp = false): DomainResult =
    var ips = initTable[string, IPv4]()
    ips["10.0.0.1"] = newIPv4("10.0.0.1", "host.test", @["a." & domain]).addOpenPorts(@[80])
    DomainResult(domain: domain, status: dsOk, udpEnabled: udp,
                 subdomains: @[newSubdomain("a." & domain, @["10.0.0.1"])], ips: ips)

proc capture(body: proc ()): string =
    ## Captures what `body` writes to stdout.
    let path = getTempDir() / "domainim_capture.txt"
    flushFile(stdout)
    let saved = dup(1)
    let f = open(path, fmWrite)
    discard dup2(getFileHandle(f), 1)
    body()
    flushFile(stdout)
    discard dup2(saved, 1)
    discard close(saved)
    f.close()
    result = readFile(path)
    removeFile(path)

suite "single-domain output matches the baseline":
    test "JSON is the plain array":
        let r = okResult("one.test")
        let legacy = generateJsonResults(r.subdomains, r.ips, false)
        check generateMultiJsonResults(@[r]) == legacy
        let j = parseJson(legacy)
        check j.kind == JArray
        check j[0].keys.toSeq == @["subdomain", "ipv6", "data"]
        check j[0]["data"][0].keys.toSeq == @["ipv4", "vhosts", "reverse_dns", "ports"]
        check parseJson(generateMultiJsonResults(@[r])) == j

    test "single UDP JSON keeps the UDP fields":
        let r = okResult("one.test", true)
        let j = parseJson(generateMultiJsonResults(@[r]))
        check j[0]["data"][0].hasKey("udp_ports")
        check j[0]["data"][0].hasKey("udp_open_filtered")

    test "terminal text equals printResults":
        let r = okResult("one.test")
        let a = capture(proc () = printResults(r.subdomains, r.ips, r.udpEnabled))
        let b = capture(proc () = printDomainResults(@[r]))
        check a.len > 0
        check a == b
        check "Domain 1/1" notin b
        check "Summary" notin b

suite "multi-domain JSON":
    setup:
        let results = @[okResult("a.test"),
                        DomainResult(domain: "b.test", status: dsNoSubdomains),
                        DomainResult(domain: "c.test", status: dsError, error: "boom"),
                        okResult("d.test")]
        let j = parseJson(generateMultiJsonResults(results))

    test "root shape and order":
        check j.keys.toSeq == @["domains"]
        check j["domains"].len == 4
        var names: seq[string]
        for d in j["domains"]: names.add d["domain"].getStr
        check names == @["a.test", "b.test", "c.test", "d.test"]

    test "statuses":
        var st: seq[string]
        for d in j["domains"]: st.add d["status"].getStr
        check st == @["ok", "no_subdomains", "error", "ok"]

    test "results are filled only for ok domains":
        check j["domains"][0]["results"].len == 1
        check j["domains"][0]["results"][0]["subdomain"].getStr == "a.a.test"
        check j["domains"][1]["results"] == newJArray()
        check j["domains"][2]["results"] == newJArray()

    test "error key only on error":
        check not j["domains"][0].hasKey("error")
        check not j["domains"][1].hasKey("error")
        check j["domains"][2]["error"].getStr == "boom"
        check not j["domains"][3].hasKey("error")

    test "two domains never use the single-domain shape":
        let two = parseJson(generateMultiJsonResults(@[okResult("a.test"), okResult("b.test")]))
        check two.kind == JObject

suite "summary and headers":
    test "summary counts":
        let rs = @[okResult("a.test"),
                   DomainResult(domain: "b.test", status: dsNoSubdomains),
                   DomainResult(domain: "c.test", status: dsError, error: "x"),
                   DomainResult(domain: "d.test", status: dsError, error: "y")]
        check summaryLine(rs) == "[*] Summary: 1 ok, 1 empty, 2 failed (c.test, d.test)"
        check summaryLine(@[okResult("a.test")]) == "[*] Summary: 1 ok, 0 empty, 0 failed"

    test "domain header":
        check domainHeader("a.test", 2, 5) == "[*] Domain 2/5: a.test"

    test "multi-domain terminal output has headers and summary":
        let rs = @[okResult("a.test"), DomainResult(domain: "b.test", status: dsError, error: "boom")]
        let o = capture(proc () = printDomainResults(rs))
        check "Domain 1/2: a.test" in o
        check "Domain 2/2: b.test" in o
        check "[!] Failed: boom" in o
        check "Summary: 1 ok, 0 empty, 1 failed (b.test)" in o

suite "per-domain isolation":
    test "a failing domain does not stop later domains":
        var seen: seq[string]
        var errors: seq[string]
        let rs = runDomains(@["a.test", "bad.test", "c.test"], false,
            proc (d: string, i: int): DomainResult =
                seen.add d
                if d == "bad.test":
                    raise newException(IOError, "network down")
                okResult(d),
            proc (d, msg: string) = errors.add d & ":" & msg)
        check seen == @["a.test", "bad.test", "c.test"]
        check rs.len == 3
        check rs[0].status == dsOk
        check rs[1].status == dsError
        check rs[1].error == "network down"
        check rs[1].domain == "bad.test"
        check rs[1].subdomains.len == 0
        check rs[2].status == dsOk
        check rs[2].domain == "c.test"
        check errors == @["bad.test:network down"]

    test "first domain failing still reports the second":
        let rs = runDomains(@["bad.test", "ok.test"], false,
            proc (d: string, i: int): DomainResult =
                if i == 0: raise newException(ValueError, "bad")
                okResult(d),
            proc (d, msg: string) = discard)
        check rs.len == 2
        check rs[0].status == dsError
        check rs[1].status == dsOk

    test "shared options reach every domain and the index is passed":
        let udp = true
        var calls: seq[(string, int, bool)]
        let rs = runDomains(@["a.test", "b.test", "c.test"], udp,
            proc (d: string, i: int): DomainResult =
                calls.add (d, i, udp)
                if i == 1: raise newException(CatchableError, "x")
                okResult(d, udp),
            proc (d, msg: string) = discard)
        check calls == @[("a.test", 0, true), ("b.test", 1, true), ("c.test", 2, true)]
        for r in rs: check r.udpEnabled
        check summaryLine(rs) == "[*] Summary: 2 ok, 0 empty, 1 failed (b.test)"

    test "results keep input order and non-failing statuses":
        let rs = runDomains(@["a.test", "e.test"], false,
            proc (d: string, i: int): DomainResult =
                if d == "e.test": DomainResult(domain: d, status: dsNoSubdomains)
                else: okResult(d),
            proc (d, msg: string) = discard)
        check rs[0].domain == "a.test"
        check rs[1].status == dsNoSubdomains
