# Module web

## Shared HTTP helper for the passive subdomain engines.
## Every network/HTTP failure is converted to a `WebpageParseError` so a
## single broken engine never terminates the run.

import std/[asyncdispatch, httpclient, strutils]
import utils

const
    userAgent* = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
    engineTimeout* = 45000 # 45s per request

proc getBody(client: AsyncHttpClient, engine: string, url: string, httpMethod: HttpMethod,
            body: string): Future[string] {.async.} =
    let resp = await client.request(url, httpMethod, body)
    if not resp.code.is2xx:
        raise newException(WebpageParseError, "$1 responded with status code $2" % [engine, $resp.code.int])
    return await resp.body

proc fetchImpl(engine: string, url: string, httpMethod: HttpMethod, body: string,
               headers: HttpHeaders): Future[string] {.async.} =
    let client = newAsyncHttpClient(userAgent)
    client.headers = headers
    try:
        let req = client.getBody(engine, url, httpMethod, body)
        if not await withTimeout(req, engineTimeout): # single deadline for headers + body
            raise newException(WebpageParseError, "$1 request timeout" % engine)
        result = req.read()
    except WebpageParseError:
        raise
    except CatchableError as e:
        raise newException(WebpageParseError, "$1 request failed ($2)" % [engine, e.msg.splitLines()[0]])
    finally:
        client.close()

proc fetch*(engine: string, url: string, httpMethod = HttpGet, body = "",
            headers: openArray[(string, string)] = []): Future[string] =
    ## Requests `url` and returns the response body. Raises `WebpageParseError`
    ## (with `engine` in the message) on timeout, network error or non-2xx status.
    fetchImpl(engine, url, httpMethod, body, newHttpHeaders(headers))
