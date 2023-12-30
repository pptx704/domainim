# Module processors

import modules/[subfinder, vhostname, iputils, scanner, scannerutils]
import std/[sequtils, tables, posix, strutils, syncio, algorithm]
import helpers

# Change file descriptor limit
var rlimit = RLimit()
discard getrlimit(RLIMIT_NOFILE, rlimit)
rlimit.rlim_cur = rlimit.rlim_max-1
discard setrlimit(RLIMIT_NOFILE, rlimit)

proc processSubdomains*(domain: string, dnsStr: string, sbList: string, throttle: int): seq[Subdomain] =
    var 
        subdomains: seq[string]
        dnsStr = dnsStr
        sbList = sbList
        subFile: File
        bruteSubs: seq[Subdomain]
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

    try:
        discard createDnsClient(dnsStr)
    except:
        dnsStr = ""
        printMsg(neutral, "[!] Given DNS Resolver seems to be invalid. Using default DNS server.")
    if subFile.open(sbList):
        subFile.close
    else:
        sbList = ""
        printMsg(error, "[!] Could not open wordlist. Bruteforcing will be skipped.")

    
    if sbList != "":
        printMsg(info, "[ ] Bruteforcing subdomains. This might take some time.")
        try:
            startProgress()
            bruteSubs = subBrute(sbList, domain, dnsStr, throttle)
            finishProgress("[+] Subdomain bruteforcing completed.")
        except WildcardError as e:
            clearLast()
            printUpdate(error, "[-] " & e.msg)
    else:
        printMsg(neutral, "[*] Skipping subdomain bruteforcing.")

    if len(subdomains) == 0 and len(bruteSubs) == 0:
        printMsg(error, "[-] No subdomains found. Aborting process.")
        return
            
    printMsg(info, "[ ] Resolving IPv4 addresses")
    result = resolveAll(subdomains, domain, dnsStr)
    result = merge(result, bruteSubs)
    result.sort
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
    startProgress()
    for ip in ips.keys:
        updateProgress(prog, ips.len, " ($1)" % ip)
        var ports = scanPorts(ip, ports)
        result[ip] = addOpenPorts(ips[ip], ports)
        inc(prog)
    finishProgress("[+] Scanned open ports")

proc processPortString*(portStr: string): seq[int] =
    if portStr == "":
        return parsePorts("none")        
    return parsePorts(portStr)