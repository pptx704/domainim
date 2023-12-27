# Module processors

import modules/[subfinder, vhostname, iputils, scanner]
import std/[terminal, sequtils, tables, posix, strutils]
import helpers

# Change file descriptor limit
var rlimit = RLimit()
discard getrlimit(RLIMIT_NOFILE, rlimit)
rlimit.rlim_cur = 65535
discard setrlimit(RLIMIT_NOFILE, rlimit)

proc processSubdomains*(domain: string): seq[Subdomain] =
    var subdomains: seq[string]
    styledEcho "Provided domain: ", styleUnderscore, domain
    printMsg(info, "[ ] Fetching subdomains (engine: dnsdumpster.com)")
    try:
        subdomains = getDDSubs(domain)
        printUpdate(success, "[+] Fetched subdomains (engine: dnsdupster.com)")
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
    printMsg(info, "[ ] Scanning ports")
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
    finishProgress("[+] Retreived virtual hostnames")