# Module subfinder

import std/asyncdispatch
import sf/[utils, dnsdumpster, crtsh, anubis, hackertarget, certspotter, rapiddns, brute]
export utils, dnsdumpster, crtsh, anubis, hackertarget, certspotter, rapiddns, brute

type Engine* = tuple
    name: string
    getSubs: proc(domain: string): Future[seq[string]] {.nimcall.}
    certBased: bool # names come from issued TLS certificates, so they are not wildcard artifacts

## Passive subdomain engines. Each one raises `WebpageParseError` on failure.
let engines*: seq[Engine] = @[
    ("dnsdumpster.com", getDDSubs, false),
    ("crt.sh", getCrtSubs, true),
    ("anubisdb.com", getAnubisSubs, false),
    ("hackertarget.com", getHTSubs, false),
    ("certspotter.com", getCertSpotterSubs, true),
    ("rapiddns.io", getRapidDNSSubs, false),
]
