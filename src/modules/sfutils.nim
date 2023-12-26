# Module sfutils

import std/[asyncdispatch, strutils, algorithm, sequtils] # Importing modules from stdlib
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

proc clean(sub: Subdomain, target: string): string =
    var data = sub.url.strip(trailing=false, chars = {'.', '*'})
    if target notin data:
        return ""
    if target != data and ("." & target) notin data:
        return ""
    return data

proc resolveDomain(subdomain: string): Future[Subdomain] {.async.} =
    let allIpv4 = await asyncResolveIpv4(client, subdomain)
    var validIPv4s: seq[string] = @[]
    for i in allIpv4:
        if isLoopBackIP(i):
            continue
        validIPv4s.add(i)
    return newSubdomain(subdomain, validIPv4s)

proc resolveAll*(subdomains: seq[Subdomain], domain: string): seq[Subdomain] =
    var subs = subdomains
    subs.sort(proc (x, y: Subdomain): int = cmp(x.url, y.url))
    subs = deduplicate(subs, isSorted=true)
    var futures: seq[Future[Subdomain]] = @[]
    for i in subs:
        var cleanUrl = clean(i, domain)
        case cleanUrl
        of "":
            continue
        else:
            futures.add(resolveDomain(cleanUrl))
    
    for i in futures:
        try:
            var sub = waitFor i
            result.add(sub)
        except Exception:
            continue

type WebpageParseError* = object of CatchableError