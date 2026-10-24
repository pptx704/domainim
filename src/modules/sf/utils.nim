# Module sfutils

import std/[asyncdispatch, strutils, algorithm, sequtils, tables, random, sets]
import ndns
import "../iputils"

type
    Subdomain* = object
        url*: string
        isAlive*: bool # consists 1 or more ip4 addresses
        ipv4*: seq[string]
        ipv6*: seq[string]

    ResolvedHost* = object
        url*: string
        ipv4*: seq[string]
        ipv6*: seq[string]

    WebpageParseError* = object of CatchableError

proc newSubdomain*(url:string, ipv4:seq[string] = @[], ipv6:seq[string] = @[]): Subdomain =
    Subdomain(url: url, isAlive: bool(len(ipv4) != 0 or len(ipv6) != 0), ipv4: ipv4, ipv6: ipv6)

proc tableToSubdomains*(subTable: Table[string, seq[string]], subTable6: Table[string, seq[string]] = initTable[string, seq[string]]()): seq[Subdomain] =
    for i in subTable.keys:
        result.add(newSubdomain(i, subTable[i], subTable6.getOrDefault(i)))
    for i in subTable6.keys:
        if i notin subTable:
            result.add(newSubdomain(i, @[], subTable6[i]))

proc `<`*(x, y : Subdomain): bool = x.url < y.url

proc merge*(sub1, sub2: seq[Subdomain]): seq[Subdomain] =
    var resTable, resTable6: Table[string, seq[string]]
    for i in sub1:
        resTable[i.url] = i.ipv4
        resTable6[i.url] = i.ipv6
    
    for i in sub2:
        if i.url notin resTable:
            resTable[i.url] = i.ipv4
            resTable6[i.url] = i.ipv6
            continue
        resTable[i.url] = deduplicate(resTable[i.url].concat(i.ipv4))
        resTable6[i.url] = deduplicate(resTable6[i.url].concat(i.ipv6))
    
    result = tableToSubdomains(resTable, resTable6)
    result.sort()

proc `==`*(sub1, sub2: Subdomain): bool =
    return sub1.url == sub2.url

proc clean(sub: string, target: string): string =
    let data = sub.strip(chars = {'.', '*', ' ', '\t', '\r'}).toLowerAscii
    if target != data and not data.endsWith("." & target):
        return ""
    return data

proc cleanAll*(subs: seq[string], target: string): seq[string] =
    ## Normalizes the given hostnames and keeps only unique (sub)domains of `target`
    let target = target.toLowerAscii
    var seen: HashSet[string]
    for i in subs:
        let res = clean(i, target)
        if res != "" and not seen.containsOrIncl(res):
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

proc resolveAaaa(client: DnsClient, subdomain: string): Future[seq[string]] {.async.} =
    ## AAAA lookup that never fails: any error yields an empty list.
    try:
        let all = await asyncResolveIpv6(client, subdomain, 1000)
        for i in all:
            let ip = canonicalIPv6(i)
            if ip != "":
                result.add(ip)
        result = deduplicate(result)
    except CatchableError:
        result = @[]

proc resolveDomain*(subdomain: string, client: DnsClient, throttle: int = 1000): Future[ResolvedHost] {.async.} =
    await sleepAsync(rand(throttle))
    let
        aFuture = asyncResolveIpv4(client, subdomain, 1000)
        aaaaFuture = resolveAaaa(client, subdomain)
    var validIPv4s: seq[string] = @[]
    try:
        let allIpv4 = await aFuture
        for i in allIpv4:
            if isLoopBackIP(i):
                continue
            validIPv4s.add(i)
    except CatchableError as e:
        discard await aaaaFuture # let the AAAA lookup finish before failing
        raise e
    let ipv6 = await aaaaFuture
    return ResolvedHost(url: subdomain, ipv4: validIPv4s, ipv6: ipv6)

proc resolveAll*(subdomains: seq[string], domain: string, dnsStr: string = ""): seq[Subdomain] =
    var 
        client = createDnsClient(dnsStr)
        subs = subdomains
        resTable, resTable6: Table[string, seq[string]]
        futures: seq[Future[ResolvedHost]] = @[]
    subs = cleanAll(subs, domain)
    for i in subs:
        resTable[i] = @[]
        resTable6[i] = @[]
        futures.add(resolveDomain(i, client))
    
    for i in futures:
        try:
            let res = waitFor i
            resTable[res.url] = deduplicate(resTable[res.url].concat(res.ipv4))
            resTable6[res.url] = deduplicate(resTable6[res.url].concat(res.ipv6))
        except CatchableError:
            continue
    
    result = tableToSubdomains(resTable, resTable6)
    result.sort()
