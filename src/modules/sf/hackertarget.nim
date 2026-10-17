# Module hackertarget

## Free API usage is limited per IP (~20 queries/day). Errors and quota
## messages are returned with status 200 as plain text.

import std/[asyncdispatch, strutils, uri]
import utils, web

const
    engine = "hackertarget.com"
    htUrl = "https://api.hackertarget.com/hostsearch/"

proc getHTSubs*(domain: string): Future[seq[string]] {.async.} =
    # ack.nmap.org,50.116.1.184
    # scanme.nmap.org,45.33.32.156
    let body = await fetch(engine, htUrl & "?" & encodeQuery({"q": domain}))
    for line in body.splitLines:
        let pair = line.split(",")
        if pair.len == 2 and ' ' notin pair[0]:
            result.add(pair[0])
    if len(result) == 0:
        let msg = body.strip.splitLines()[0]
        raise newException(WebpageParseError, "A records not found (engine: hackertarget.com)" &
            (if msg.len != 0 and msg.len < 120: " - " & msg else: ""))
