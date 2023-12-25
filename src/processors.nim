# Module processors

import modules/[subfinder, vhostname, iputils]
import std/[terminal, sequtils, tables]
import helpers

proc processSubdomains*(domain: string): seq[Subdomain] =
    styledEcho "Provided domain: ", styleUnderscore, domain
    printMsg(info, "[ ] Fetching subdomains (engine: dnsdumpster.com)")
    var subdomains = getDDSubs(domain)
    printUpdate(success, "[+] Fetched subdomains (engine: dnsdupster.com)")
    printMsg(info, "[ ] Fetching subdomains (engine: cert.sh)")
    subdomains = subdomains.concat(getCrtSubs(domain))
    printUpdate(success, "[+] Fetched subdomains (engine: cert.sh)")
    printMsg(info, "[ ] Resolving IPv4 addresses")
    result = resolveAll(subdomains, domain)
    printUpdate(success, "[+] Resolved IPv4 addresses")

proc processVHostNames*(subdomains: seq[Subdomain]): Table[string, IPv4] =
    printMsg(info, "[ ] Querying virtual hostnames")
    result = getVHostTable(subdomains)
    printUpdate(success, "[+] Retreived virtual hostnames")