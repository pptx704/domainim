# Module processors

import modules/[subfinder, vhostname, iputils, scanner, scannerutils]
import std/[sequtils, tables, posix, strutils]
import helpers

# Change file descriptor limit
var rlimit = RLimit()
discard getrlimit(RLIMIT_NOFILE, rlimit)
rlimit.rlim_cur = rlimit.rlim_max-1
discard setrlimit(RLIMIT_NOFILE, rlimit)

proc processSubdomains*(domain: string): seq[Subdomain] =
    var subdomains: seq[string]
    printMsg(info, "[ ] Fetching subdomains (engine: dnsdumpster.com)")
    try:
        subdomains = getDDSubs(domain)
        printUpdate(success, "[+] Fetched subdomains (engine: dnsdumpster.com)")
    except WebpageParseError as e:
        printUpdate(error, "[-] " & e.msg)
    printMsg(info, "[ ] Fetching subdomains (engine: crt.sh)")
    try:
        subdomains = subdomains.concat(getCrtSubs(domain))
        printUpdate(success, "[+] Fetched subdomains (engine: crt.sh)")
    except WebpageParseError as e:
        printUpdate(error, "[-] " & e.msg)
    if len(subdomains) == 0:
        printMsg(error, "[-] No subdomains found. Aborting...")
        return
    printMsg(info, "[ ] Resolving IPv4 addresses")
    result = resolveAll(subdomains, domain)
    printUpdate(success, "[+] Resolved IPv4 addresses")

proc processVHostNames*(subdomains: seq[Subdomain]): Table[string, IPv4] =
    printMsg(info, "[ ] Querying virtual hostnames")
    startProgress()
    result = getVHostTable(subdomains)
    finishProgress("[+] Retreived virtual hostnames")

proc processOpenPorts*(ips: Table[string, IPv4], ports: seq[int]): Table[string, IPv4] =
    if len(ports) == 0:
        return ips
    printMsg(info, "[ ] Scanning ports ($1 ports for each ip)" % $ports.len)
    var 
        prog: int = 0
        pbar: int = 0
    startProgress()
    for ip in ips.keys:
        updateProgress(pbar, " ($1)" % ip)
        var ports = scanPorts(ip, ports)
        result[ip] = addOpenPorts(ips[ip], ports)
        prog += 1
        pbar = (prog * 100 / len(ips)).toInt()
    finishProgress("[+] Scanned open ports")

proc processPortString*(portStr: string): seq[int] =
    if portStr == "":
        return parsePorts("none")        
    return parsePorts(portStr)