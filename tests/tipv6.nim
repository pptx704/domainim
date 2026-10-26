import std/[unittest, json, tables, sets, asyncdispatch, options, strutils, sequtils, algorithm]
import ../src/results
import ../src/modules/[iputils, subfinder, vhostname]
import ../src/modules/sf/brute

proc ok(v: seq[string]): Future[seq[string]] =
    result = newFuture[seq[string]]("ok")
    result.complete(v)

proc failing(): Future[seq[string]] =
    result = newFuture[seq[string]]("failing")
    result.fail(newException(IOError, "dns failure"))

proc wc(ips: varargs[string]): HashSet[string] = ips.toHashSet

suite "canonicalIPv6":
    test "valid addresses are compressed and lowercased":
        check canonicalIPv6("2001:DB8::1") == "2001:db8::1"
        check canonicalIPv6("2001:0db8:0000:0000:0000:0000:0000:0001") == "2001:db8::1"
        check canonicalIPv6(" 2001:db8::1 ") == "2001:db8::1"

    test "equivalent notations give one canonical string":
        let forms = ["2001:db8::1", "2001:DB8:0:0:0:0:0:1", "2001:0db8::0001"]
        check forms.mapIt(canonicalIPv6(it)).deduplicate == @["2001:db8::1"]

    test "unspecified, loopback, link-local and IPv4-mapped are rejected":
        for ip in ["::", "::1", "0:0:0:0:0:0:0:1", "fe80::1", "FE80::abcd", "febf::1",
                   "::ffff:1.2.3.4", "::ffff:0102:0304"]:
            check canonicalIPv6(ip) == ""

    test "fec0 (not link-local) and global addresses are kept":
        check canonicalIPv6("fec0::1") == "fec0::1"
        check canonicalIPv6("::2") == "::2"

    test "garbage and IPv4 input are rejected":
        for ip in ["", "garbage", "1.2.3.4", "2001:db8::g", "12345::1", ":::", "2001:db8::1/64"]:
            check canonicalIPv6(ip) == ""

suite "subdomain model":
    test "isAlive rules":
        check not newSubdomain("a.test").isAlive
        check newSubdomain("a.test", @["1.1.1.1"]).isAlive
        check newSubdomain("a.test", @[], @["2001:db8::1"]).isAlive
        check newSubdomain("a.test", @["1.1.1.1"], @["2001:db8::1"]).isAlive

    test "IPv6 stays in its own field":
        let s = newSubdomain("a.test", @["1.1.1.1"], @["2001:db8::1"])
        check s.ipv4 == @["1.1.1.1"]
        check s.ipv6 == @["2001:db8::1"]

    test "merge deduplicates both families independently":
        let m = merge(@[newSubdomain("a.test", @["1.1.1.1"], @["2001:db8::1"])],
                      @[newSubdomain("a.test", @["1.1.1.1", "2.2.2.2"], @["2001:db8::1", "2001:db8::2"]),
                        newSubdomain("b.test", @[], @["2001:db8::3"])])
        check m.len == 2
        check m[0].ipv4 == @["1.1.1.1", "2.2.2.2"]
        check m[0].ipv6 == @["2001:db8::1", "2001:db8::2"]
        check m[1].ipv4.len == 0
        check m[1].ipv6 == @["2001:db8::3"]
        check m[1].isAlive

    test "tableToSubdomains keeps IPv6-only hosts":
        let subs = tableToSubdomains({"a.test": @["1.1.1.1"]}.toTable, {"b.test": @["2001:db8::1"]}.toTable)
        check subs.len == 2
        for s in subs:
            if s.url == "a.test": check s.ipv6.len == 0
            else: check s.ipv4.len == 0 and s.ipv6 == @["2001:db8::1"]

suite "resolution result handling":
    test "a failing AAAA lookup still yields the A addresses":
        let r = waitFor combineHost("a.test", ok(@["1.1.1.1", "2.2.2.2"]), failing())
        check r.ipv4 == @["1.1.1.1", "2.2.2.2"]
        check r.ipv6.len == 0

    test "an empty AAAA lookup still yields the A addresses":
        let r = waitFor combineHost("a.test", ok(@["1.1.1.1"]), ok(@[]))
        check r.ipv4 == @["1.1.1.1"]
        check r.ipv6.len == 0

    test "a failing A lookup still fails the host":
        expect IOError:
            discard waitFor combineHost("a.test", failing(), ok(@["2001:db8::1"]))

    test "AAAA addresses are canonicalised, filtered and kept out of ipv4":
        let r = waitFor combineHost("a.test", ok(@["127.0.0.1", "1.1.1.1"]),
            ok(@["2001:DB8::1", "2001:db8:0:0:0:0:0:1", "::1", "fe80::1", "junk"]))
        check r.ipv4 == @["1.1.1.1"]
        check r.ipv6 == @["2001:db8::1"]

    test "IPv6-only host":
        let r = waitFor combineHost("a.test", ok(@[]), ok(@["2001:db8::1"]))
        check r.ipv4.len == 0
        check r.ipv6 == @["2001:db8::1"]
        check newSubdomain(r.url, r.ipv4, r.ipv6).isAlive

    test "awaitAaaa swallows failures":
        check (waitFor awaitAaaa(failing())).len == 0

suite "wildcard handling":
    test "brute removes wildcard IPs per family":
        let r = ResolvedHost(url: "a.test", ipv4: @["1.1.1.1", "9.9.9.9"], ipv6: @["2001:db8::1", "2001:db8::9"])
        let s = bruteResult(r, wc("9.9.9.9", "2001:db8::9")).get
        check s.ipv4 == @["1.1.1.1"]
        check s.ipv6 == @["2001:db8::1"]

    test "brute keeps a host when only one family is left":
        let r = ResolvedHost(url: "a.test", ipv4: @["9.9.9.9"], ipv6: @["2001:db8::1"])
        let s = bruteResult(r, wc("9.9.9.9")).get
        check s.ipv4.len == 0
        check s.ipv6 == @["2001:db8::1"]
        let r2 = ResolvedHost(url: "a.test", ipv4: @["1.1.1.1"], ipv6: @["2001:db8::9"])
        let s2 = bruteResult(r2, wc("2001:db8::9")).get
        check s2.ipv4 == @["1.1.1.1"]
        check s2.ipv6.len == 0

    test "brute drops a host when both lists end empty":
        let r = ResolvedHost(url: "a.test", ipv4: @["9.9.9.9"], ipv6: @["2001:db8::9"])
        check bruteResult(r, wc("9.9.9.9", "2001:db8::9")).isNone
        let r6 = ResolvedHost(url: "a.test", ipv4: @[], ipv6: @["2001:db8::9"])
        check bruteResult(r6, wc("2001:db8::9")).isNone

    let wild = wc("9.9.9.9", "2001:db8::9")
    let subs = @[
        newSubdomain("kept.test", @["9.9.9.9"], @["2001:db8::9"]),
        newSubdomain("v4.test", @["1.1.1.1"], @["2001:db8::9"]),
        newSubdomain("v6.test", @["9.9.9.9"], @["2001:db8::1"]),
        newSubdomain("v6only.test", @[], @["2001:db8::1"]),
        newSubdomain("allwild.test", @["9.9.9.9"], @["2001:db8::9"]),
        newSubdomain("wild6.test", @[], @["2001:db8::9"]),
        newSubdomain("dead.test")]

    test "filterWildcard keeps hosts with any non-wildcard address of either family":
        let (res, hidden) = filterWildcard(subs, wild, wc("kept.test"))
        check res.mapIt(it.url).sorted == @["dead.test", "kept.test", "v4.test", "v6.test", "v6only.test"]
        check hidden == 2

    test "filterWildcard drops all-wildcard hosts not in keep":
        let (res, hidden) = filterWildcard(subs, wild, initHashSet[string]())
        check "kept.test" notin res.mapIt(it.url)
        check "allwild.test" notin res.mapIt(it.url)
        check "wild6.test" notin res.mapIt(it.url)
        check hidden == 3

    test "an IPv6 wildcard alone hides IPv6-only wildcard hosts but not IPv4 hosts":
        let (res, hidden) = filterWildcard(subs, wc("2001:db8::9"), initHashSet[string]())
        check "wild6.test" notin res.mapIt(it.url)
        check "allwild.test" in res.mapIt(it.url) # 9.9.9.9 is not a wildcard here
        check hidden == 1

    test "an IPv4 wildcard alone does not hide IPv6 addresses":
        let (res, hidden) = filterWildcard(subs, wc("9.9.9.9"), initHashSet[string]())
        check "wild6.test" in res.mapIt(it.url)
        check hidden == 0

    test "an empty wildcard set is a no-op":
        let (res, hidden) = filterWildcard(subs, initHashSet[string](), initHashSet[string]())
        check res == subs
        check res.mapIt(it.ipv6) == subs.mapIt(it.ipv6)
        check hidden == 0

suite "vhost table":
    test "IPv6 addresses never reach the IPv4 table":
        let (table, ips) = buildVHostTable(@[
            newSubdomain("a.test", @["1.1.1.1"], @["2001:db8::1"]),
            newSubdomain("b.test", @[], @["2001:db8::2"]),
            newSubdomain("c.test", @["1.1.1.1", "2.2.2.2"])])
        check ips == @["1.1.1.1", "2.2.2.2"]
        check table.len == 2
        for k, v in table:
            check ':' notin k
            check ':' notin v.ip
        check table["1.1.1.1"].vhostNames == @["a.test", "c.test"]
        check table["2.2.2.2"].vhostNames == @["c.test"]

    test "IPv6-only subdomains give an empty table":
        let (table, ips) = buildVHostTable(@[newSubdomain("b.test", @[], @["2001:db8::2"])])
        check table.len == 0
        check ips.len == 0
        check getVHostTable(@[newSubdomain("b.test", @[], @["2001:db8::2"])]).len == 0

suite "json output with IPv6":
    var ips = initTable[string, IPv4]()
    ips["10.0.0.1"] = newIPv4("10.0.0.1", "host.test", @["a.test"]).addOpenPorts(@[80]).addUdpPorts(@[53], @[123])
    ips["10.0.0.2"] = newIPv4("10.0.0.2")

    test "ipv6 key is present and sorted, other keys unchanged":
        let subs = @[newSubdomain("a.test", @["10.0.0.1"], @["2001:db8::2", "2001:db8::1"])]
        let j = parseJson(generateJsonResults(subs, ips, false))
        check j[0]["ipv6"] == %["2001:db8::1", "2001:db8::2"]
        check j[0]["subdomain"].getStr == "a.test"
        let d = j[0]["data"][0]
        check d["ipv4"].getStr == "10.0.0.1"
        check d["vhosts"] == %["a.test"]
        check d["reverse_dns"].getStr == "host.test"
        check d["ports"] == %[80]
        check not d.hasKey("udp_ports")
        check not d.hasKey("ipv6")
        check "2001" notin $d

    test "with UDP enabled":
        let subs = @[newSubdomain("a.test", @["10.0.0.1"], @["2001:db8::1"])]
        let j = parseJson(generateJsonResults(subs, ips, true))
        check j[0]["ipv6"] == %["2001:db8::1"]
        let d = j[0]["data"][0]
        check d["udp_ports"] == %[53]
        check d["udp_open_filtered"] == %[123]
        check "2001" notin $d

    test "IPv6-only host has the ipv6 key and no data":
        let j = parseJson(generateJsonResults(@[newSubdomain("v6.test", @[], @["2001:db8::1"])], ips, true))
        check j[0]["ipv6"] == %["2001:db8::1"]
        check j[0]["data"].len == 0

    test "A-only input gives the old content plus an empty ipv6 array":
        let subs = @[newSubdomain("a.test", @["10.0.0.1"]), newSubdomain("dead.test")]
        let j = parseJson(generateJsonResults(subs, ips, false))
        check j[0]["ipv6"].kind == JArray
        check j[0]["ipv6"].len == 0
        check j[1]["ipv6"].len == 0
        check j[1]["data"].len == 0
        var keys: seq[string]
        for k, _ in j[0]: keys.add(k)
        check keys.sorted == @["data", "ipv6", "subdomain"]
        var dkeys: seq[string]
        for k, _ in j[0]["data"][0]: dkeys.add(k)
        check dkeys.sorted == @["ipv4", "ports", "reverse_dns", "vhosts"]
