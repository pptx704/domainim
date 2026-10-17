# Module crtsh

import std/[asyncdispatch, json, strutils, uri]
import utils, web

const
    engine = "crt.sh"
    crtUrl = "https://crt.sh/"
    retries = 1 # crt.sh frequently answers with 502 under load

proc getARecords(body: string): seq[string] =
    # [{"issuer_name": "...", "common_name": "*.cloud.wazuh.com",
    #   "name_value": "*.cloud.wazuh.com\nwazuh.com", ...}]
    var data: JsonNode
    try:
        data = parseJson(body)
    except JsonParsingError:
        raise newException(WebpageParseError, "crt.sh returned an invalid response")

    # traverse the json and get the name_value
    for entry in data.getElems:
        if entry.kind == JObject and entry.hasKey("name_value"):
            for name in entry["name_value"].getStr.splitLines:
                result.add(name)

proc getCrtSubs*(domain: string): Future[seq[string]] {.async.} =
    let url = crtUrl & "?" & encodeQuery({"Identity": domain, "output": "json"})
    var body: string
    for attempt in 0..retries:
        try:
            body = await fetch(engine, url, headers = {"Accept": "application/json"})
            break
        except WebpageParseError:
            if attempt == retries:
                raise
            await sleepAsync(2000)
    result = getARecords(body)
    if len(result) == 0:
        raise newException(WebpageParseError, "A records not found (engine: crt.sh)")
