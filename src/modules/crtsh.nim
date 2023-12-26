# Module crtsh

import std/[httpclient, strformat, net]
import regex
import sfutils

const 
    crtUrl = "https://crt.sh/"
    userAgent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0"
    rowRegEx = re2"<TR>\s*<TD\s+style=\x22text-align:center\x22>[\s\S]*?</TR>"
    subdomainRegEx = re2"<TD>(.*?)</TD>"

let 
    headers = {
        "Accept": "text/html",
        "Accept-Language": "en-US,en;q=0.8",
        "Referer": "https://crt.sh/?a=1",
        "Content-Type": "application/x-www-form-urlencoded"
    }


    client: HttpClient = newHttpClient(userAgent, timeout=20000) # 20s timeout

client.headers = newHttpHeaders(headers)

proc makeRequest(url: string): Response =
    try:
        let paramUrl = fmt"{crtUrl}?Identity={url}"#&exclude=expired"
        result = client.get(paramUrl)
    except TimeoutError:
        raise newException(WebpageParseError, "crt.sh is not responding as expected")


proc getARecords(response: Response): seq[string] =
    for i in findAll(response.body, rowRegEx):
        var data = response.body[i.boundaries]
        try: 
            data = data[findAll(data, subdomainRegEx)[0].group(0)]
            var sub = data
            if sub notin result:
                result.add(sub)
        except IndexDefect:
            raise newException(WebpageParseError, "A records not found (engine: crt.sh)")
    if len(result) == 0:
        raise newException(WebpageParseError, "A records not found (engine: crt.sh)")

proc getCrtSubs*(url: string): seq[string] =
    return getARecords(makeRequest(url))