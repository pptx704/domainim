# Module dnsdumpster

## This module parses dnsdumpster to get A records for the given domain
## Currently it supports only dnsdumpster.com. 

import std/[httpclient, options]
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

    client: HttpClient = newHttpClient(userAgent, timeout=20000) # 10s timeout

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
    echo "Could not parse the csrftoken from 'dnsdumpster.com'. Check back later or update RegEx pattern."
    quit(1)

proc setCookie(response: Response) =
    let 
        cookieValue = response.headers["set-cookie"]
        csrfcookie = getFirstGroup(cookieValue, cookieRegEx)
    if isSome(csrfcookie):
        client.headers["Cookie"] = "csrftoken=" & csrfcookie.get()
        return
    echo "Could not parse the csrf cookie from 'dnsdumpster.com'. Check back later or update RegEx pattern."
    quit(1)
    

proc makeRequest(reqMethod: string, url: string): Response =
    if reqMethod == "GET":
        result = client.get(ddUrl)
    else:
        let resp = makeRequest("GET", ddUrl)
        try:
            setCookie(resp)
        except KeyError:
            echo "Could not fetch cookie from dnsdumpster."
            quit(1)
        var data = MultipartData()
        data["csrfmiddlewaretoken"] = getCSRFToken(resp)
        data["targetip"] = url
        data["user"] = "free"
        result = client.post(ddUrl, multipart = data)

proc getHostTable(str: string): string =
    try:
        let tbl_match = findAll(str, tblRegEx)[2]
        result = $str[tbl_match.boundaries]
    except IndexDefect:
        echo "Could not parse A record table from 'dnsdumpster.com'. Check back later or check if the domain is correct or update RegEx pattern."
        quit(1)

proc getARecords(response: Response): seq[SubDomain] =  
    var table = getHostTable(response.body)
    for i in findAll(table, subdomainRegEx):
        result.add(newSubdomain(table[i.group(0)]))

proc getDDSubs*(url: string): seq[SubDomain] =
    return getARecords(makeRequest("POST", url))