import std/[unittest, json, tables, strutils, os, posix, sequtils]
import ../src/[results]
import ../src/modules/[iputils, subfinder, dirbuster]

proc capture(body: proc ()): string =
    ## Captures what `body` writes to stdout, without ANSI styling.
    let path = getTempDir() / "domainim_dir_capture.txt"
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
    var plain = ""
    var i = 0
    while i < result.len:
        if result[i] == '\e':
            while i < result.len and result[i] != 'm':
                inc i
        else:
            plain.add(result[i])
        inc i
    result = plain

proc finding(scheme, path: string, status, size: int, redirect = ""): DirFinding =
    DirFinding(scheme: scheme, path: path, status: status, size: size, redirect: redirect)

proc dirResult(host, scheme: string, findings: seq[DirFinding], suppressed = 0,
               baseline = bkStable, unreachable = false): DirResult =
    DirResult(target: DirTarget(hostname: host, scheme: scheme), findings: findings,
              summary: DirSummary(baseline: baseline, suppressed: suppressed, unreachable: unreachable))

proc fixture(domain = "a.test"): (seq[Subdomain], Table[string, IPv4], seq[DirResult]) =
    var ips = initTable[string, IPv4]()
    ips["10.0.0.1"] = newIPv4("10.0.0.1").addOpenPorts(@[80])
    let subs = @[newSubdomain("www." & domain, @["10.0.0.1"]), newSubdomain("dead." & domain)]
    let dirs = @[
        dirResult("www." & domain, "https", @[finding("https", "/b", 403, 10), finding("https", "/a", 200, 100000)], 3),
        dirResult("www." & domain, "http", @[finding("http", "/z", 301, 0, "https://www." & domain & "/z"),
                                            finding("http", "/a", 200, 5)], 1),
        dirResult("dead." & domain, "http", @[], 0, bkUnreachable, true),
        dirResult("dead." & domain, "https", @[], 0, bkUnreachable, true)]
    (subs, ips, dirs)

suite "directory JSON":
    test "paths are sorted by scheme then path with hidden total":
        let (subs, ips, dirs) = fixture()
        let j = parseJson(generateJsonResults(subs, ips, false, dirs, true))
        let w = j[0]
        check w["subdomain"].getStr == "www.a.test"
        check w.keys.toSeq == @["subdomain", "ipv6", "data", "paths", "paths_hidden"]
        check w["paths"].len == 4
        let order = w["paths"].mapIt(it["scheme"].getStr & " " & it["path"].getStr)
        check order == @["http /a", "http /z", "https /a", "https /b"]
        check w["paths"][1].keys.toSeq == @["scheme", "path", "status", "size", "redirect"]
        check w["paths"][1]["redirect"].getStr == "https://www.a.test/z"
        check w["paths"][0]["redirect"].getStr == ""
        check w["paths_hidden"].getInt == 4

    test "reported size is capped":
        let (subs, ips, dirs) = fixture()
        let j = parseJson(generateJsonResults(subs, ips, false, dirs, true))
        check j[0]["paths"][2]["size"].getInt == 65536

    test "an unresolved subdomain still gets empty paths":
        let (subs, ips, dirs) = fixture()
        let j = parseJson(generateJsonResults(subs, ips, false, dirs, true))
        check j[1]["subdomain"].getStr == "dead.a.test"
        check j[1]["paths"].len == 0
        check j[1]["paths_hidden"].getInt == 0

    test "paths are absent when the feature is off":
        let (subs, ips, dirs) = fixture()
        for j in [parseJson(generateJsonResults(subs, ips, false, dirs, false)),
                  parseJson(generateJsonResults(subs, ips, false)),
                  parseJson(generateJsonResults(subs, ips, false, @[], false))]:
            for sub in j:
                check not sub.hasKey("paths")
                check not sub.hasKey("paths_hidden")
        check generateJsonResults(subs, ips, false, dirs, false) == generateJsonResults(subs, ips, false)

suite "directory terminal output":
    test "block, hidden note and unreachable note":
        let (subs, ips, dirs) = fixture()
        let text = capture(proc () = printResults(subs, ips, false, dirs, true))
        check "Paths:" in text
        check "http 200 /a 5" in text
        check "http 301 /z 0 -> https://www.a.test/z" in text
        check "https 200 /a 65536" in text
        check "https 403 /b 10" in text
        check text.find("http 200 /a") < text.find("https 200 /a")
        check "4 responses matching the soft-404 baseline hidden" in text
        check "Target unreachable over http, https" in text

    test "nothing is printed when the feature is off":
        let (subs, ips, dirs) = fixture()
        let text = capture(proc () = printResults(subs, ips, false, dirs, false))
        check "Paths" notin text
        check "soft-404" notin text
        check "unreachable" notin text
        check text == capture(proc () = printResults(subs, ips, false))

    test "a subdomain without findings or notes gets no block":
        let (subs, ips, _) = fixture()
        let text = capture(proc () = printResults(subs, ips, false, @[], true))
        check "Paths" notin text

    test "line and note helpers":
        check findingLine(finding("http", "/x", 200, 70000)) == "http 200 /x 65536"
        check findingLine(finding("http", "/x", 302, 0, "/y")) == "http 302 /x 0 -> /y"
        check hiddenNote(7) == "7 responses matching the soft-404 baseline hidden"
        check unreachableNote(@["http"]) == "Target unreachable over http"

suite "multi-domain with directories":
    test "each domain keeps its own paths":
        let (s1, i1, d1) = fixture("one.test")
        let (s2, i2, d2) = fixture("two.test")
        let results = @[
            DomainResult(domain: "one.test", status: dsOk, subdomains: s1, ips: i1, dirEnabled: true, dirResults: d1),
            DomainResult(domain: "two.test", status: dsOk, subdomains: s2, ips: i2)]
        let j = parseJson(generateMultiJsonResults(results))
        check j["domains"][0]["results"][0].hasKey("paths")
        check j["domains"][0]["results"][0]["paths"][0]["path"].getStr == "/a"
        check not j["domains"][1]["results"][0].hasKey("paths")
        let text = capture(proc () = printDomainResults(results))
        let (first, second) = (text.split("Domain 2/2")[0], text.split("Domain 2/2")[1])
        check "Paths:" in first
        check "Paths:" notin second
        check "Domain 1/2: one.test" in text

    test "a single domain is the plain array with paths":
        let (s, i, d) = fixture()
        let r = DomainResult(domain: "a.test", status: dsOk, subdomains: s, ips: i, dirEnabled: true, dirResults: d)
        check generateMultiJsonResults(@[r]) == generateJsonResults(s, i, false, d, true)
        check parseJson(generateMultiJsonResults(@[r])).kind == JArray
        let off = DomainResult(domain: "a.test", status: dsOk, subdomains: s, ips: i, dirResults: d)
        check "paths" notin generateMultiJsonResults(@[off])
        check capture(proc () = printDomainResults(@[off])) == capture(proc () = printResults(s, i))
