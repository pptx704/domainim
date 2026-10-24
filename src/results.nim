import helpers
import std/[terminal, strutils, tables, json, algorithm]
import modules/[iputils, subfinder, dirbuster]

const maxReportedSize = 65536

proc findingsFor*(dirs: seq[DirResult], url: string): seq[DirFinding] =
    ## Findings of every scheme of one subdomain, sorted by scheme then path.
    for d in dirs:
        if d.target.hostname == url:
            result.add(d.findings)
    result.sort(proc (a, b: DirFinding): int =
        result = cmp(a.scheme, b.scheme)
        if result == 0: result = cmp(a.path, b.path)
        if result == 0: result = cmp(a.status, b.status))

proc hiddenFor*(dirs: seq[DirResult], url: string): int =
    for d in dirs:
        if d.target.hostname == url:
            result += d.summary.suppressed

proc unreachableFor*(dirs: seq[DirResult], url: string): seq[string] =
    ## Schemes of the subdomain that answered no probe.
    for d in dirs:
        if d.target.hostname == url and d.summary.unreachable:
            result.add(d.target.scheme)
    result.sort()

proc findingLine*(f: DirFinding): string =
    result = f.scheme & " " & $f.status & " " & f.path & " " & $min(f.size, maxReportedSize)
    if f.redirect != "":
        result.add(" -> " & f.redirect)

proc hiddenNote*(hidden: int): string =
    return $hidden & " responses matching the soft-404 baseline hidden"

proc unreachableNote*(schemes: seq[string]): string =
    return "Target unreachable over " & schemes.join(", ")

proc statusColor(status: int): ForegroundColor =
    case status div 100
    of 2: fgGreen
    of 3: fgCyan
    of 4: fgYellow
    of 5: fgRed
    else: fgWhite

proc printPaths(dirs: seq[DirResult], url: string) =
    let
        findings = findingsFor(dirs, url)
        hidden = hiddenFor(dirs, url)
        down = unreachableFor(dirs, url)
    if findings.len == 0 and hidden == 0 and down.len == 0:
        return
    styledEcho "  ↳ ", styleBright, "Paths: "
    for f in findings:
        stdout.write "      " & f.scheme & " "
        stdout.styledWrite statusColor(f.status), $f.status
        stdout.write " " & f.path & " " & $min(f.size, maxReportedSize)
        if f.redirect != "":
            stdout.write " -> " & f.redirect
        stdout.write "\n"
    if hidden > 0:
        echo "    ", hiddenNote(hidden)
    if down.len > 0:
        echo "    ", unreachableNote(down)

proc printResults*(subdomains: seq[Subdomain], ips: Table[string, IPv4], udpEnabled: bool = false,
                   dirs: seq[DirResult] = @[], dirEnabled: bool = false) =
    printMsg(neutral, "[*] Printing results\n")
    for s in subdomains:
        styledEcho styleUnderscore, s.url
        if s.ipv4.len == 0 and s.ipv6.len == 0:
            styledEcho "  ↳ ", fgRed, styleBright, styleUnderscore, "Public IPv4 not found\n"
            if dirEnabled:
                printPaths(dirs, s.url)
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
        if dirEnabled:
            printPaths(dirs, s.url)

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
        dirEnabled*: bool
        dirResults*: seq[DirResult]

proc pathsJson(dirs: seq[DirResult], url: string): JsonNode =
    result = newJArray()
    for f in findingsFor(dirs, url):
        result.add(%*{"scheme": f.scheme, "path": f.path, "status": f.status,
                      "size": min(f.size, maxReportedSize), "redirect": f.redirect})

proc buildJsonResults(subdomains: seq[Subdomain], ips: Table[string, IPv4], udpEnabled: bool,
                      dirs: seq[DirResult] = @[], dirEnabled: bool = false): JsonNode =
    var res = newJArray()

    for s in subdomains:
        var sub: JsonNode = newJObject()
        sub["subdomain"] = %s.url
        sub["ipv6"] = %s.ipv6.sorted
        sub["data"] = newJArray()
        if dirEnabled:
            sub["paths"] = pathsJson(dirs, s.url)
            sub["paths_hidden"] = %hiddenFor(dirs, s.url)
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

proc generateJsonResults*(subdomains: seq[Subdomain], ips: Table[string, IPv4], udpEnabled: bool,
                          dirs: seq[DirResult] = @[], dirEnabled: bool = false): string =
    return buildJsonResults(subdomains, ips, udpEnabled, dirs, dirEnabled).pretty

proc generateMultiJsonResults*(results: seq[DomainResult]): string =
    ## One domain keeps the plain array; several use the {"domains": [...]} shape.
    if results.len == 1:
        let r = results[0]
        return generateJsonResults(r.subdomains, r.ips, r.udpEnabled, r.dirResults, r.dirEnabled)
    var domains = newJArray()
    for r in results:
        var d = newJObject()
        d["domain"] = %r.domain
        d["status"] = %($r.status)
        if r.status == dsOk:
            d["results"] = buildJsonResults(r.subdomains, r.ips, r.udpEnabled, r.dirResults, r.dirEnabled)
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
        printResults(r.subdomains, r.ips, r.udpEnabled, r.dirResults, r.dirEnabled)
        return
    for i, r in results:
        printMsg(neutral, domainHeader(r.domain, i + 1, results.len))
        case r.status
        of dsOk:
            printResults(r.subdomains, r.ips, r.udpEnabled, r.dirResults, r.dirEnabled)
        of dsNoSubdomains:
            printMsg(error, "[-] No subdomains found for " & r.domain)
        of dsError:
            printMsg(error, "[!] Failed: " & r.error)
    printMsg(info, summaryLine(results))

proc saveResults*(subdomains: seq[Subdomain], ips: Table[string, IPv4], outfile: File, udpEnabled: bool = false,
                  dirs: seq[DirResult] = @[], dirEnabled: bool = false) =
    let outstr = generateJsonResults(subdomains, ips, udpEnabled, dirs, dirEnabled)
    outfile.write(outstr)

proc saveDomainResults*(results: seq[DomainResult], outfile: File) =
    outfile.write(generateMultiJsonResults(results))
