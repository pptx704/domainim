# Module dnsdumpster

## This module parses dnsdumpster to get A records for the given domain
## Currently it supports only dnsdumpster.com. 

import std/[httpclient, options, strutils, net]
import regex
import sfutils

const 
    ddUrl = "https://dnsdumpster.com/"
    userAgent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0"
    csrfRegEx = re2"<input type=\x22hidden\x22 name=\x22csrfmiddlewaretoken\x22 value=\x22(.*?)\x22>"
    tblRegEx = re2"<table class=\x22table\x22 style=\x22font-size: 1.1em; font-family: 'Courier New', Courier, monospace;\x22>[\s\S]*?</table>"
    subdomainRegEx = re2"<tr><td class=\x22col-md-4\x22>(.*?)<br>"
    cookieRegEx = re2"csrftoken=(.*?);"

let 
    headers = {
        "Accept": "text/html",
        "Accept-Language": "en-US,en;q=0.8",
        "Referer": "https://dnsdumpster.com",
        "Content-Type": "application/x-www-form-urlencoded"
    }

    client: HttpClient = newHttpClient(userAgent, timeout=20000) # 20s timeout

client.headers = newHttpHeaders(headers)

proc getFirstGroup(str: string, rgx: Regex2): Option[string] =
    var match: RegexMatch2
    if find(str, rgx, match):
        result = some($str[match.group(0)])
    else:
        result = none(string)

proc getCSRFToken(response: Response): string =
    let token = getFirstGroup(response.body, csrfRegEx)
    if isSome(token):
        return get(token)
    raise newException(WebpageParseError, "Could not parse CSRF token from dnsdumpster")

proc setCookie(response: Response) =
    let 
        cookieValue = response.headers["set-cookie"]
        csrfcookie = getFirstGroup(cookieValue, cookieRegEx)
    if isSome(csrfcookie):
        client.headers["Cookie"] = "csrftoken=" & csrfcookie.get()
        return
    raise newException(WebpageParseError, "Could not get csrftoken Cookie from dnsdumpster")

proc makeRequest(reqMethod: string, url: string): Response =
    if reqMethod == "GET":
        result = client.get(ddUrl)
    else:
        var resp: Response
        resp = makeRequest("GET", ddUrl)
        try:
            setCookie(resp)
        except KeyError, TimeoutError:
            raise newException(WebpageParseError, "dnsdumpster.com is not responding as expected")

        var data = MultipartData()
        data["csrfmiddlewaretoken"] = getCSRFToken(resp)
        data["targetip"] = url
        data["user"] = "free"
        try:
            result = client.post(ddUrl, multipart = data)
        except TimeoutError:
            raise newException(WebpageParseError, "dnsdumpster.com is not responding as expected")
        if parseInt(result.status.split()[0]) >= 400:
            raise newException(WebpageParseError, "dnsdumpster.com is not responding as expected")

proc getHostTable(str: string): string =
    try:
        let tbl_match = findAll(str, tblRegEx)[2]
        result = $str[tbl_match.boundaries]
    except IndexDefect:
        raise newException(WebpageParseError, "A records not found (engine: dnsdumpster.com)")

proc getARecords(response: Response): seq[string] =  
    var table = getHostTable(response.body)
    for i in findAll(table, subdomainRegEx):
        result.add(table[i.group(0)])

proc getDDSubs*(url: string): seq[string] =
    return getARecords(makeRequest("POST", url))