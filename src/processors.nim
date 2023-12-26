# Module processors

import modules/[subfinder, vhostname, iputils]
import std/[terminal, sequtils, tables]
import helpers

proc processSubdomains*(domain: string): seq[Subdomain] =
    var subdomains: seq[Subdomain]
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