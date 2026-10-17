# Module anubis

import std/[asyncdispatch, json]
import utils, web

const
    engine = "anubisdb.com"
    anubisUrl = "https://anubisdb.com/anubis/subdomains/"

proc getAnubisSubs*(domain: string): Future[seq[string]] {.async.} =
    # ["ack.nmap.org", "nmap.org", "scanme.nmap.org"]
    let body = await fetch(engine, anubisUrl & domain, headers = {"Accept": "application/json"})
    try:
        for name in parseJson(body).getElems:
            result.add(name.getStr)
    except JsonParsingError:
        raise newException(WebpageParseError, "anubisdb.com returned an invalid response")
    if len(result) == 0:
        raise newException(WebpageParseError, "A records not found (engine: anubisdb.com)")
