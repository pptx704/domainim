# Module dnsdumpster

## This module parses dnsdumpster to get A records for the given domain
## Currently it supports only dnsdumpster.com. Free users are limited to
## 50 results per domain.

import std/[asyncdispatch, httpclient, uri]
import regex
import utils, web

const
    engine = "dnsdumpster.com"
    ddUrl = "https://dnsdumpster.com/htmld/"
    tblRegEx = re2"<table id=\x22a_rec_table\x22>[\s\S]*?</table>"
    subdomainRegEx = re2"<tr>\s*<td>([^<]+)</td>"

proc getARecords(body: string): seq[string] =
    var tbl: RegexMatch2
    if not find(body, tblRegEx, tbl):
        raise newException(WebpageParseError, "A records not found (engine: dnsdumpster.com)")
    let table = body[tbl.boundaries]
    for i in findAll(table, subdomainRegEx):
        result.add(table[i.group(0)])

proc getDDSubs*(domain: string): Future[seq[string]] {.async.} =
    let body = await fetch(engine, ddUrl, HttpPost, encodeQuery({"target": domain}), {
        "Content-Type": "application/x-www-form-urlencoded",
        "HX-Request": "true",
        "Referer": "https://dnsdumpster.com/",
        "Origin": "https://dnsdumpster.com"
    })
    return getARecords(body)
