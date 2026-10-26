import std/[oids, asyncdispatch, strutils, sets, sequtils, options]
import utils
import ndns
import "../../helpers"

const
    batchSize = 1024 # arbitrary
    wildcardProbes = 3 # wildcards are often round-robin, so probe more than once

proc buildSub(sub: string, domain: string): string = sub & "." & domain

proc getWildcardIPs*(domain: string, dns: string = ""): HashSet[string] =
    ## Resolves a few random labels. Any IP returned belongs to a wildcard record.
    let client = createDnsClient(dns)
    var futures: seq[Future[ResolvedHost]]
    for _ in 1..wildcardProbes:
        futures.add(resolveDomain(buildSub($genOid(), domain), client, 0))
    for f in futures:
        try:
            let res = waitFor f
            for ip in res.ipv4 & res.ipv6:
                result.incl(ip)
        except CatchableError:
            continue

proc filterWildcard*(subs: seq[Subdomain], wildcardIPs: HashSet[string], keep: HashSet[string]): (seq[Subdomain], int) =
    ## Drops subdomains that resolve only to wildcard IPs, unless they are in `keep`.
    ## Returns the remaining subdomains and the number of dropped ones.
    if wildcardIPs.len == 0:
        return (subs, 0)
    for s in subs:
        if s.url in keep or not s.isAlive or s.ipv4.anyIt(it notin wildcardIPs) or
           s.ipv6.anyIt(it notin wildcardIPs):
            result[0].add(s)
        else:
            inc(result[1])

proc bruteResult*(res: ResolvedHost, wildcardIPs: HashSet[string]): Option[Subdomain] =
    ## Removes wildcard IPs from both families. The host is dropped when nothing is left.
    let
        v4 = res.ipv4.filterIt(it notin wildcardIPs)
        v6 = res.ipv6.filterIt(it notin wildcardIPs)
    if v4.len == 0 and v6.len == 0:
        return none(Subdomain)
    some(newSubdomain(res.url, v4, v6))

proc brute(subs: seq[string], client: DnsClient, throttle: int, wildcardIPs: HashSet[string]): seq[Subdomain] =
    var futures: seq[Future[ResolvedHost]] = @[]

    for i in subs:
        futures.add(resolveDomain(i, client, throttle))

    for i in futures:
        try:
            let sub = bruteResult(waitFor i, wildcardIPs)
            if sub.isSome:
                result.add(sub.get)
        except CatchableError:
            continue

proc subBrute*(wordlist: string, domain: string, dns: string = "", throttle: int = 1000,
               wildcardIPs: HashSet[string] = initHashSet[string]()): seq[Subdomain] =
    ## Bruteforces subdomains of `domain` from `wordlist`. IPs in `wildcardIPs`
    ## (see `getWildcardIPs`) are discarded from the results.
    let client = createDnsClient(dns)
    var words: seq[string]
    for line in wordlist.lines:
        let word = line.strip()
        if word.len != 0 and not word.startsWith("#"):
            words.add(word)

    var cur = 0
    while cur < words.len:
        let last = min(cur + batchSize, words.len)
        var subs = newSeqOfCap[string](last - cur)
        for word in words.toOpenArray(cur, last - 1):
            subs.add(buildSub(word, domain))
        result &= brute(subs, client, throttle, wildcardIPs)
        cur = last
        updateProgress(cur, words.len, " ($1 found)" % $result.len)
