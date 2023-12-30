# Module vhost
import std/[tables, asyncdispatch]
import iputils, subfinder
import ndns
import "../helpers"

let client = initSystemDnsClient()

proc getRDNS(ip: string): Future[(string, string)] {.async.} =
    var rdns: seq[string]
    try:
        rdns = await client.asyncResolveRDns(ip)
    except TimeoutError:
        return (ip, "")
    except ResponseIdNotEqualError:
        rdns = await client.asyncResolveRDns(ip)
    if len(rdns) == 0:
        return (ip, "")
    return (ip, rdns[0])

proc getVHostTable*(subdomains: seq[Subdomain]): Table[string, IPv4] =
    var futures: seq[Future[(string, string)]]
    var progress = 0
    for s in subdomains:
        for i in s.ipv4:
            if i notin result:
                result[i] = newIPv4(i)
            result[i].vhostNames.add(s.url)
            futures.add(getRDNS(i))
            inc(progress)
            updateProgress((progress/2).toInt, futures.len)

    progress = 0
    for i in futures:
        var res = waitFor i
        inc(progress)
        result[res[0]].rdns = res[1]
        var pbar = (progress/2 + futures.len/2).toInt
        updateProgress(pbar, futures.len)