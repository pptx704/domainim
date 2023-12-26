# Module vhost
import std/[tables, asyncdispatch]
import iputils, sfutils
import ndns
import "../helpers"

let client = initDnsClient("1.1.1.1", Port(53))

proc getVHost(ip: string): Future[IPv4] {.async.} =
    var vhost: seq[string]
    try:
        vhost = await client.asyncResolveRDns(ip)
    except TimeoutError:
        return newIPv4(ip)
        # echo "Timeout for " & ip
    if len(vhost) == 0:
        return newIPv4(ip)
    return newIPv4(ip, vhost[0])

proc getVHostTable*(subdomains: seq[Subdomain]): Table[string, IPv4] =
    var futures: seq[Future[IPv4]]
    var progress = 0
    for s in subdomains:
        for i in s.ipv4:
            futures.add(getVHost(i))
            progress += 1
            var pbar = (progress * 50 / len(subdomains)).toInt()
            updateProgress(pbar)
    progress = 0
    for i in futures:
        var res = waitFor i
        progress += 1
        result[res.ip] = res
        var pbar = (progress * 50 / len(subdomains)).toInt() + 50
        updateProgress(pbar)