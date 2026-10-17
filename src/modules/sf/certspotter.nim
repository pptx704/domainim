# Module certspotter

## Without an API key, only currently valid certificates are returned and
## requests are rate limited (~10/hour).

import std/[asyncdispatch, json, uri]
import utils, web

const
    engine = "certspotter.com"
    csUrl = "https://api.certspotter.com/v1/issuances"

proc getCertSpotterSubs*(domain: string): Future[seq[string]] {.async.} =
    # [{"id": "15974896708", "dns_names": ["issues.nmap.org", "nmap.org", ...], ...}]
    let
        url = csUrl & "?" & encodeQuery({"domain": domain, "include_subdomains": "true", "expand": "dns_names"})
        body = await fetch(engine, url, headers = {"Accept": "application/json"})
    try:
        for cert in parseJson(body).getElems:
            for name in cert{"dns_names"}.getElems:
                result.add(name.getStr)
    except JsonParsingError:
        raise newException(WebpageParseError, "certspotter.com returned an invalid response")
    if len(result) == 0:
        raise newException(WebpageParseError, "A records not found (engine: certspotter.com)")
