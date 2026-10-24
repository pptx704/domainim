import std/[unittest, json, tables]
import ../src/results
import ../src/modules/[iputils, subfinder]

proc sample(): (seq[Subdomain], Table[string, IPv4]) =
    var ips = initTable[string, IPv4]()
    ips["10.0.0.1"] = newIPv4("10.0.0.1", "host.test", @["a.test"])
        .addOpenPorts(@[80, 443])
        .addUdpPorts(@[53], @[123, 161])
    ips["10.0.0.2"] = newIPv4("10.0.0.2")
    (@[newSubdomain("a.test", @["10.0.0.1"]), newSubdomain("dead.test"),
       newSubdomain("b.test", @["10.0.0.2"])], ips)

suite "result model":
    test "TCP and UDP results are stored separately":
        let ip = newIPv4("1.2.3.4").addOpenPorts(@[80]).addUdpPorts(@[53], @[123])
        check ip.openPorts == @[80]
        check ip.udpOpenPorts == @[53]
        check ip.udpOpenFilteredPorts == @[123]

    test "adding TCP ports keeps UDP ports and vice versa":
        let ip = newIPv4("1.2.3.4").addUdpPorts(@[53], @[123]).addOpenPorts(@[22])
        check ip.openPorts == @[22]
        check ip.udpOpenPorts == @[53]
        check ip.udpOpenFilteredPorts == @[123]
        let ip2 = ip.addUdpPorts(@[], @[])
        check ip2.openPorts == @[22]
        check ip2.udpOpenPorts.len == 0

    test "open|filtered is not an open port":
        let ip = newIPv4("1.2.3.4").addUdpPorts(@[], @[123])
        check ip.openPorts.len == 0
        check ip.udpOpenPorts.len == 0

suite "json output":
    test "without UDP the output has the TCP fields only":
        let (subs, ips) = sample()
        let j = parseJson(generateJsonResults(subs, ips, false))
        check j.len == 3
        let d = j[0]["data"][0]
        check d["ipv4"].getStr == "10.0.0.1"
        check d["ports"] == %[80, 443]
        check d["reverse_dns"].getStr == "host.test"
        check d["vhosts"] == %["a.test"]
        check not d.hasKey("udp_ports")
        check not d.hasKey("udp_open_filtered")
        check j[1]["data"].len == 0

    test "with UDP the results land in the UDP fields only":
        let (subs, ips) = sample()
        let j = parseJson(generateJsonResults(subs, ips, true))
        let d = j[0]["data"][0]
        check d["ports"] == %[80, 443]
        check d["udp_ports"] == %[53]
        check d["udp_open_filtered"] == %[123, 161]
        # a host with no UDP results still gets empty UDP lists
        let e = j[2]["data"][0]
        check e["ports"].len == 0
        check e["udp_ports"].len == 0
        check e["udp_open_filtered"].len == 0

    test "open|filtered ports never appear in ports or udp_ports":
        let (subs, ips) = sample()
        let d = parseJson(generateJsonResults(subs, ips, true))[0]["data"][0]
        for p in [123, 161]:
            check %p notin d["ports"].getElems
            check %p notin d["udp_ports"].getElems
        check %53 notin d["ports"].getElems
        check %53 notin d["udp_open_filtered"].getElems
