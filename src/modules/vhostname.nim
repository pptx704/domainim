# Module vhost
import std/[tables, asyncdispatch]
import iputils, subfinder
import ndns
import "../helpers"

const batchSize = 256

proc getRDNS(ip: string, client: DnsClient): Future[(string, string)] {.async.} =
    var rdns: seq[string]
    for attempt in 0..1: # retry once (e.g. on ResponseIdNotEqualError)
        try:
            rdns = await client.asyncResolveRDns(ip)
            break
        except CatchableError:
            continue
    if len(rdns) == 0:
        return (ip, "")
    return (ip, rdns[0])

proc getVHostTable*(subdomains: seq[Subdomain], dnsStr: string = ""): Table[string, IPv4] =
    let client = createDnsClient(dnsStr)
    var ips: seq[string]
    for s in subdomains:
        for i in s.ipv4:
            if i notin result:
                result[i] = newIPv4(i)
                ips.add(i) # one rDNS query per unique IP
            result[i].vhostNames.add(s.url)

    # query in batches so large targets don't flood the resolver
    var cur = 0
    while cur < ips.len:
        let last = min(cur + batchSize, ips.len)
        var futures: seq[Future[(string, string)]]
        for ip in ips.toOpenArray(cur, last - 1):
            futures.add(getRDNS(ip, client))
        for f in futures:
            let (ip, rdns) = waitFor f
            result[ip].rdns = rdns
            inc(cur)
            updateProgress(cur, ips.len)
