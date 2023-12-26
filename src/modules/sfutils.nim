# Module sfutils

import std/[asyncdispatch, strutils, algorithm, sequtils, tables] # Importing modules from stdlib
import ndns
import iputils

type
    Subdomain* = object
        url*: string
        isAlive*: bool
        ipv4*: seq[string]

let client = initSystemDnsClient()

proc newSubdomain*(url:string, ipv4:seq[string] = @[]): Subdomain =
    Subdomain(url: url, isAlive: bool(len(ipv4) != 0), ipv4: ipv4)

proc `==`*(sub1, sub2: Subdomain): bool =
    return sub1.url == sub2.url

proc contains(subdomains: seq[Subdomain], sub: Subdomain): bool =
    for i in subdomains:
        if i == sub:
            return true
    return false

proc clean(sub: string, target: string): string =
    var data = sub.strip(trailing=false, chars = {'.', '*'})
    if target notin data:
        return ""
    if target != data and ("." & target) notin data:
        return ""
    return data

proc resolveDomain(subdomain: string): Future[(string, seq[string])] {.async.} =
    let allIpv4 = await asyncResolveIpv4(client, subdomain)
    var validIPv4s: seq[string] = @[]
    for i in allIpv4:
        if isLoopBackIP(i):
            continue
        validIPv4s.add(i)
    return (subdomain, validIPv4s)

proc resolveAll*(subdomains: seq[string], domain: string): seq[Subdomain] =
    var subs = subdomains
    subs = deduplicate(subs, isSorted=true)
    var resTable: Table[string, seq[string]]
    var futures: seq[Future[(string, seq[string])]] = @[]
    for i in subs:
        var cleanUrl = clean(i, domain)
        case cleanUrl
        of "":
            continue
        else:
            resTable[cleanUrl] = @[]
            futures.add(resolveDomain(cleanUrl))
    
    for i in futures:
        try:
            var res = waitFor i
            resTable[res[0]] = resTable[res[0]].concat(res[1])
            resTable[res[0]] = deduplicate(resTable[res[0]])
        except Exception as e:
            continue
    for i in resTable.keys:
        result.add(newSubdomain(i, resTable[i]))
    result.sort(proc (x, y: Subdomain): int = cmp(x.url, y.url))
    result = deduplicate(result, isSorted=true)

type WebpageParseError* = object of CatchableError