# Module rapiddns

## Parses the rapiddns.io subdomain table. Only the first ~100 rows are
## available without an account.

import std/asyncdispatch
import regex
import utils, web

const
    engine = "rapiddns.io"
    rdUrl = "https://rapiddns.io/subdomain/"
    subdomainRegEx = re2"<td>([A-Za-z0-9._*-]+)</td>"

proc getRapidDNSSubs*(domain: string): Future[seq[string]] {.async.} =
    # <td>analizame2.nmap.org</td>
    # <td><a href="/sameip/50.116.1.184#result" ...>50.116.1.184</a></td>
    # <td>A</td>
    let body = await fetch(engine, rdUrl & domain & "?full=1")
    for m in findAll(body, subdomainRegEx):
        result.add(body[m.group(0)]) # non-hostname cells are dropped by cleanAll
    if len(result) == 0:
        raise newException(WebpageParseError, "A records not found (engine: rapiddns.io)")
