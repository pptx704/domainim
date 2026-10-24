import helpers
import std/[terminal, strutils, tables, json, algorithm]
import modules/[iputils, subfinder]

proc printResults*(subdomains: seq[Subdomain], ips: Table[string, IPv4], udpEnabled: bool = false) =
    printMsg(neutral, "[*] Printing results\n")
    for s in subdomains:
        styledEcho styleUnderscore, s.url
        if s.ipv4.len == 0 and s.ipv6.len == 0:
            styledEcho "  ↳ ", fgRed, styleBright, styleUnderscore, "Public IPv4 not found\n"
            continue
        for ip in s.ipv4:
            styledEcho "  ↳ ", fgGreen, styleUnderscore, ip
            let
                vhostnames = ips[ip].vhostNames.join(", ")
                rdns = ips[ip].rdns
                ports = ips[ip].openPorts
                udpOpen = ips[ip].udpOpenPorts
                udpOpenFiltered = ips[ip].udpOpenFilteredPorts
            if rdns == "":
                discard
            else:
                styledEcho "    ↳ ", styleBright, "Reverse DNS: ", resetStyle, rdns
            if vhostnames == "":
                discard
            else:
                styledEcho "    ↳ ", styleBright, "Virtual Hostnames: ", resetStyle, vhostnames
            if len(ports) == 0:
                discard
            else:
                styledEcho "    ↳ ", styleBright, "Open Ports: ", resetStyle, fgGreen, ports.join(", ")
            if udpEnabled:
                if len(udpOpen) != 0:
                    styledEcho "    ↳ ", styleBright, "Open UDP Ports: ", resetStyle, fgGreen, udpOpen.join(", ")
                if len(udpOpenFiltered) != 0:
                    styledEcho "    ↳ ", styleBright, "Open|Filtered UDP Ports: ", resetStyle, fgYellow, udpOpenFiltered.join(", ")
            echo " "
        if s.ipv6.len != 0:
            styledEcho "  ↳ ", styleBright, "IPv6: ", resetStyle, fgGreen, s.ipv6.sorted.join(", ")
            echo " "

type
    DomainStatus* = enum
        dsOk = "ok", dsNoSubdomains = "no_subdomains", dsError = "error"

    DomainResult* = object
        domain*: string
        status*: DomainStatus
        error*: string
        subdomains*: seq[Subdomain]
        ips*: Table[string, IPv4]
        udpEnabled*: bool

proc buildJsonResults(subdomains: seq[Subdomain], ips: Table[string, IPv4], udpEnabled: bool): JsonNode =
    var res = newJArray()

    for s in subdomains:
        var sub: JsonNode = newJObject()
        sub["subdomain"] = %s.url
        sub["ipv6"] = %s.ipv6.sorted
        sub["data"] = newJArray()
        if s.ipv4.len == 0:
            res.add(sub)
            continue
        for ip in s.ipv4:
            var subData = newJObject()
            subData["ipv4"] = %ip
            subData["vhosts"] = %ips[ip].vhostnames
            subData["reverse_dns"] = %ips[ip].rdns
            subData["ports"] = %ips[ip].openPorts
            if udpEnabled:
                subData["udp_ports"] = %ips[ip].udpOpenPorts
                subData["udp_open_filtered"] = %ips[ip].udpOpenFilteredPorts
            sub["data"].add(subData)
        res.add(sub)
    return res

proc generateJsonResults*(subdomains: seq[Subdomain], ips: Table[string, IPv4], udpEnabled: bool): string =
    return buildJsonResults(subdomains, ips, udpEnabled).pretty

proc generateMultiJsonResults*(results: seq[DomainResult]): string =
    ## One domain keeps the plain array; several use the {"domains": [...]} shape.
    if results.len == 1:
        let r = results[0]
        return generateJsonResults(r.subdomains, r.ips, r.udpEnabled)
    var domains = newJArray()
    for r in results:
        var d = newJObject()
        d["domain"] = %r.domain
        d["status"] = %($r.status)
        if r.status == dsOk:
            d["results"] = buildJsonResults(r.subdomains, r.ips, r.udpEnabled)
        else:
            d["results"] = newJArray()
        if r.status == dsError:
            d["error"] = %r.error
        domains.add(d)
    var root = newJObject()
    root["domains"] = domains
    return root.pretty

proc domainHeader*(domain: string, index, total: int): string =
    return "[*] Domain " & $index & "/" & $total & ": " & domain

proc summaryLine*(results: seq[DomainResult]): string =
    var ok, empty, failed = 0
    var failedNames: seq[string]
    for r in results:
        case r.status
        of dsOk: inc ok
        of dsNoSubdomains: inc empty
        of dsError:
            inc failed
            failedNames.add(r.domain)
    result = "[*] Summary: " & $ok & " ok, " & $empty & " empty, " & $failed & " failed"
    if failed > 0:
        result.add(" (" & failedNames.join(", ") & ")")

proc printDomainResults*(results: seq[DomainResult]) =
    ## One domain prints exactly like printResults; several get a header each and a closing summary.
    if results.len == 1:
        let r = results[0]
        printResults(r.subdomains, r.ips, r.udpEnabled)
        return
    for i, r in results:
        printMsg(neutral, domainHeader(r.domain, i + 1, results.len))
        case r.status
        of dsOk:
            printResults(r.subdomains, r.ips, r.udpEnabled)
        of dsNoSubdomains:
            printMsg(error, "[-] No subdomains found for " & r.domain)
        of dsError:
            printMsg(error, "[!] Failed: " & r.error)
    printMsg(info, summaryLine(results))

proc saveResults*(subdomains: seq[Subdomain], ips: Table[string, IPv4], outfile: File, udpEnabled: bool = false) =
    let outstr = generateJsonResults(subdomains, ips, udpEnabled)
    outfile.write(outstr)

proc saveDomainResults*(results: seq[DomainResult], outfile: File) =
    outfile.write(generateMultiJsonResults(results))
