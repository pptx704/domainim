import std/[oids, asyncdispatch, strutils, memfiles]
import utils
import ndns
import "../../helpers"

type WildcardError* = object of CatchableError

let maxFiles = 1024 # arbitrary

proc buildSub(sub: string, domain: string): string = $sub & "." & domain

proc checkWildcard(domain: string, client: DnsClient): bool =
    let 
        fakesub = buildSub($genOid(), domain)
        res = (waitFor resolveDomain(fakesub, client))[1]
    
    if res.len != 0:
        return true

proc brute(subs: seq[string], client: DnsClient, throttle: int): seq[Subdomain] =
    var futures: seq[Future[(string, seq[string])]] = @[]

    for i in subs:
        futures.add(resolveDomain(i, client, throttle))
    
    for i in futures:
        try:
            var res = waitFor i
            if res[1].len == 0:
                continue
            result.add(newSubdomain(res[0], res[1]))
        except Exception:
            continue

proc subBrute*(wordlist: string, domain: string, dns: string = "", throttle: int = 1000): seq[Subdomain] =
    var client = createDnsClient(dns)

    if checkWildcard(domain, client):
        raise newException(WildcardError, "$1 seems to have a wildcard record. Skipping bruteforcing." % domain)

    var 
        subs: seq[string]
        file = syncio.open(wordlist)
        counterFile = memfiles.open(wordlist)
        total = 0
        i = 0
        found = 0
        cur = 0
    
    for line in memSlices(counterFile):
        inc(total)
    counterFile.close()

    for line in file.lines:
        subs.add(buildSub(line.strip(), domain))
        inc(i)
        inc(cur)
        if i == maxFiles:
            result &= brute(subs, client, throttle)
            found = result.len
            i = 0
            subs = @[]
            updateProgress(cur, total, "($1 found)" % $found)
    file.close()