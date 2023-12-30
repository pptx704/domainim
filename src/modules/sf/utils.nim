# Module sfutils

import std/[asyncdispatch, strutils, algorithm, sequtils, tables, random]
import ndns
import "../iputils"

type
    Subdomain* = object
        url*: string
        isAlive*: bool
        ipv4*: seq[string]

proc newSubdomain*(url:string, ipv4:seq[string] = @[]): Subdomain =
    Subdomain(url: url, isAlive: bool(len(ipv4) != 0), ipv4: ipv4)

proc tableToSubdomains*(subTable: Table[string, seq[string]]): seq[Subdomain] =
    for i in subTable.keys:
        result.add(newSubdomain(i, subTable[i]))

proc `<`*(x, y : Subdomain): bool = x.url < y.url

proc merge*(sub1, sub2: seq[Subdomain]): seq[Subdomain] =
    var resTable: Table[string, seq[string]]
    for i in sub1:
        resTable[i.url] = i.ipv4
    
    for i in sub2:
        if i.url notin resTable:
            resTable[i.url] = i.ipv4
            continue
        resTable[i.url] = resTable[i.url].concat(i.ipv4)
        resTable[i.url] = deduplicate(resTable[i.url])
    
    result = tableToSubdomains(resTable)
    result.sort()

proc `==`*(sub1, sub2: Subdomain): bool =
    return sub1.url == sub2.url

proc clean(sub: string, target: string): string =
    var data = sub.strip(trailing=false, chars = {'.', '*'})
    if target notin data:
        return ""
    if target != data and not data.endsWith("." & target):
        return ""
    return data

proc cleanAll*(subs: seq[string], target: string): seq[string] =
    for i in subs:
        var res = clean(i, target)
        if res != "":
            result.add(res)

proc createDnsClient*(dnsStr: string): DnsClient =
    if dnsStr == "":
        result = initSystemDnsClient()
        return
    if "#" in dnsStr:
        let 
            splitted = dnsStr.split("#", maxSplit = 1)
            ip = splitted[0]
            port = splitted[1].parseInt
        result = initDnsClient(ip, Port(port))
        return
    else:
        result = initDnsClient(dnsStr)

proc resolveDomain*(subdomain: string, client: DnsClient, throttle: int = 300): Future[(string, seq[string])] {.async.} =
    await sleepAsync(rand(throttle))
    let allIpv4 = await asyncResolveIpv4(client, subdomain, 1000)
    var validIPv4s: seq[string] = @[]
    for i in allIpv4:
        if isLoopBackIP(i):
            continue
        validIPv4s.add(i)
    return (subdomain, validIPv4s)

proc resolveAll*(subdomains: seq[string], domain: string, dnsStr: string = ""): seq[Subdomain] =
    var 
        client = createDnsClient(dnsStr)
        subs = subdomains
        resTable: Table[string, seq[string]]
        futures: seq[Future[(string, seq[string])]] = @[]
    subs = cleanAll(subs, domain)
    for i in subs:
        resTable[i] = @[]
        futures.add(resolveDomain(i, client))
    
    for i in futures:
        try:
            var res = waitFor i
            resTable[res[0]] = resTable[res[0]].concat(res[1])
            resTable[res[0]] = deduplicate(resTable[res[0]])
        except Exception:
            continue
    
    result = tableToSubdomains(resTable)
    result.sort()

type WebpageParseError* = object of CatchableError