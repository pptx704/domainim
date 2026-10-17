# Module processors

import modules/[subfinder, vhostname, iputils, scanner, scannerutils]
import std/[sequtils, tables, posix, strutils, syncio, algorithm, math, asyncdispatch, sets, options]
import helpers

# Change file descriptor limit
var rlimit = RLimit()
discard getrlimit(RLIMIT_NOFILE, rlimit)
rlimit.rlim_cur = rlimit.rlim_max-1
discard setrlimit(RLIMIT_NOFILE, rlimit)

proc startPassiveSubs(domain: string): seq[Future[seq[string]]] =
    ## Starts all engines concurrently. They progress whenever the event loop
    ## runs, i.e. also while bruteforcing.
    for engine in engines:
        result.add(engine.getSubs(domain))

proc collectPassiveSubs(futures: seq[Future[seq[string]]], domain: string): (seq[string], Option[HashSet[string]]) =
    ## Waits for the engines. A failing engine never aborts the run.
    ## Returns all subdomains and the ones seen in TLS certificates (none if
    ## no certificate based engine responded).
    printMsg(info, "[ ] Waiting for passive engines")
    var msgs: seq[(MsgType, string)]
    for i, f in futures:
        try:
            let subs = cleanAll(waitFor f, domain)
            result[0].add(subs)
            if engines[i].certBased:
                result[1] = some(result[1].get(initHashSet[string]()) + subs.toHashSet)
            msgs.add((success, "[+] Fetched $1 subdomains (engine: $2)" % [$subs.len, engines[i].name]))
        except WebpageParseError as e:
            msgs.add((error, "[-] " & e.msg))
        except CatchableError as e:
            msgs.add((error, "[-] $1 failed ($2)" % [engines[i].name, e.msg]))
    clearLast()
    for (msgtype, msg) in msgs:
        printMsg(msgtype, msg)

proc processSubdomains*(domain: string, dnsStr: string, sbList: string, rps: int, forceBrute: bool): seq[Subdomain] =
    var 
        sbList = sbList
        subFile: File
        bruteSubs: seq[Subdomain]
        throttle: int = round(1024*1000/rps).toInt
    let engineFutures = startPassiveSubs(domain)
    printMsg(neutral, "[*] Fetching subdomains from $1 engines in the background" % $engines.len)
    let wildcardIPs = getWildcardIPs(domain, dnsStr)
    if wildcardIPs.len != 0:
        printMsg(neutral, "[*] Wildcard record found ($1)." % wildcardIPs.toSeq.sorted.join(", "))

    if not sbList.isEmptyOrWhitespace:
        if subFile.open(sbList):
            subFile.close
        else:
            sbList = ""
            printMsg(error, "[!] Could not open wordlist. Bruteforcing will be skipped.")

    if sbList != "":
        if wildcardIPs.len != 0 and not forceBrute:
            printMsg(error, "[-] Bruteforcing skipped because of the wildcard record. Use --force-brute to bruteforce anyway.")
        else:
            if wildcardIPs.len != 0:
                printMsg(neutral, "[*] Bruteforced subdomains resolving only to wildcard IPs will be discarded.")
            printMsg(info, "[ ] Bruteforcing subdomains. This might take some time.")
            startProgress()
            bruteSubs = subBrute(sbList, domain, dnsStr, throttle, wildcardIPs)
            finishProgress("[+] Subdomain bruteforcing completed ($1 found)." % $bruteSubs.len)
    else:
        printMsg(neutral, "[*] Skipping subdomain bruteforcing.")

    let (subdomains, certSubs) = collectPassiveSubs(engineFutures, domain)

    if len(subdomains) == 0 and len(bruteSubs) == 0:
        return
            
    printMsg(info, "[ ] Resolving IPv4 addresses")
    var hidden: int
    result = resolveAll(subdomains, domain, dnsStr)
    if certSubs.isSome:
        (result, hidden) = filterWildcard(result, wildcardIPs, certSubs.get + [domain].toHashSet)
    result = merge(result, bruteSubs)
    result.sort
    printUpdate(success, "[+] Resolved IPv4 addresses")
    if wildcardIPs.len != 0 and certSubs.isNone:
        printMsg(neutral, "[*] No certificate engine responded. Subdomains resolving only to wildcard IPs are not hidden.")
    if hidden != 0:
        printMsg(neutral, "[*] Hid $1 subdomains resolving only to wildcard IPs (not seen in certificates)." % $hidden)

proc processDnsString*(dnsStr: string): string =
    ## Returns `dnsStr` if it is a valid resolver, otherwise "" (system default)
    try:
        discard createDnsClient(dnsStr)
        result = dnsStr
    except CatchableError:
        printMsg(neutral, "[!] Given DNS Resolver seems to be invalid. Using default DNS server.")

proc processVHostNames*(subdomains: seq[Subdomain], dnsStr: string): Table[string, IPv4] =
    printMsg(info, "[ ] Querying virtual hostnames")
    startProgress()
    result = getVHostTable(subdomains, dnsStr)
    finishProgress("[+] Retrieved virtual hostnames")

proc processOpenPorts*(ips: Table[string, IPv4], ports: seq[int]): Table[string, IPv4] =
    if len(ports) == 0:
        return ips
    printMsg(info, "[ ] Scanning ports ($1 ports for each of $2 IPs)" % [$ports.len, $ips.len])
    startProgress()
    var lastPercent = 0
    let openPorts = scanHosts(ips.keys.toSeq, ports, proc(done, total: int) =
        let percent = done * 100 div total
        if percent != lastPercent: # avoid redrawing for every connection attempt
            lastPercent = percent
            updateProgress(done, total, " ($1/$2 connections)" % [$done, $total]))
    for ip, ipv4 in ips:
        result[ip] = addOpenPorts(ipv4, openPorts.getOrDefault(ip))
    finishProgress("[+] Scanned open ports")

proc processPortString*(portStr: string): seq[int] =
    if portStr == "":
        return parsePorts("none")        
    return parsePorts(portStr)