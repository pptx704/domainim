import std/[unittest, asyncdispatch, asyncnet, nativesockets, net, strutils, times]
import ../src/modules/dirbuster

# A loopback HTTP server that answers every path with a scripted response.

type
    Handler = proc (path: string, client: AsyncSocket): Future[void] {.closure.}
    Server = ref object
        sock: AsyncSocket
        port: int
        requests: seq[string]

proc serve(s: Server, handler: Handler) {.async.} =
    while true:
        var client: AsyncSocket
        try:
            client = await s.sock.accept()
        except CatchableError:
            return
        proc session(c: AsyncSocket) {.async.} =
            try:
                let line = await c.recvLine()
                while true:
                    let header = await c.recvLine()
                    if header in ["\r\n", ""]:
                        break
                let path = line.split(' ')[1]
                s.requests.add(path)
                await handler(path, c)
            except CatchableError:
                discard
            finally:
                c.close()
        asyncCheck session(client)

proc startServer(handler: Handler): Server =
    result = Server(sock: newAsyncSocket())
    result.sock.setSockOpt(OptReuseAddr, true)
    result.sock.bindAddr(Port(0), "127.0.0.1")
    result.sock.listen()
    result.port = result.sock.getLocalAddr()[1].int
    asyncCheck serve(result, handler)

proc target(s: Server): DirTarget =
    DirTarget(hostname: "127.0.0.1:" & $s.port, scheme: "http")

proc status(code: int, reason: string, headers = "", body = ""): string =
    "HTTP/1.1 " & $code & " " & reason & "\r\nContent-Length: " & $body.len & "\r\n" &
        "Connection: close\r\n" & headers & "\r\n" & body

suite "real HTTP client":
    test "200 reports status and body size":
        let srv = startServer(proc (p: string, c: AsyncSocket) {.async.} =
            await c.send(status(200, "OK", body = "x".repeat(1234))))
        let r = waitFor httpRequest(srv.target, "/ok")
        srv.sock.close()
        check r.ok
        check r.status == 200
        check r.size == 1234

    test "301 is reported with its Location and not followed":
        let srv = startServer(proc (p: string, c: AsyncSocket) {.async.} =
            if p == "/old":
                await c.send(status(301, "Moved Permanently", "Location: /new\r\n"))
            else:
                await c.send(status(200, "OK", body = "followed")))
        let r = waitFor httpRequest(srv.target, "/old")
        srv.sock.close()
        check r.ok
        check r.status == 301
        check r.location == "/new"
        check srv.requests == @["/old"]

    test "404 and 403 are answers":
        let srv = startServer(proc (p: string, c: AsyncSocket) {.async.} =
            if p == "/secret":
                await c.send(status(403, "Forbidden", body = "no"))
            else:
                await c.send(status(404, "Not Found")))
        let a = waitFor httpRequest(srv.target, "/missing")
        let b = waitFor httpRequest(srv.target, "/secret")
        srv.sock.close()
        check a.ok and a.status == 404 and a.size == 0
        check b.ok and b.status == 403 and b.size == 2

    test "a large body is capped and the rest is not read":
        const chunk = 16384
        const total = 128 * 1024 * 1024
        var sent = 0
        let srv = startServer(proc (p: string, c: AsyncSocket) {.async.} =
            await c.send("HTTP/1.1 200 OK\r\nContent-Length: " & $total & "\r\nConnection: close\r\n\r\n")
            let data = "y".repeat(chunk)
            while sent < total:
                # an empty flag set makes a closed connection raise instead of passing silently
                await c.send(data, flags = {})
                sent += chunk)
        let r = waitFor httpRequest(srv.target, "/big")
        srv.sock.close()
        check r.ok
        check r.status == 200
        check r.size == bodyCap
        check bodyCap == 65536
        # drain the server side for a moment so a still-reading client would show up
        waitFor sleepAsync(200)
        check sent < total div 4

    test "a body just over the cap is reported as the cap":
        let srv = startServer(proc (p: string, c: AsyncSocket) {.async.} =
            await c.send(status(200, "OK", body = "z".repeat(bodyCap + 10))))
        let r = waitFor httpRequest(srv.target, "/")
        srv.sock.close()
        check r.size == bodyCap

    test "a stalled body hits the total deadline":
        var release = newFuture[void]("release")
        let srv = startServer(proc (p: string, c: AsyncSocket) {.async.} =
            await c.send("HTTP/1.1 200 OK\r\nContent-Length: 100000\r\nConnection: close\r\n\r\nabc")
            await release)
        let t0 = epochTime()
        let r = waitFor httpRequestWithin(srv.target, "/stall", 400)
        let took = epochTime() - t0
        release.complete()
        srv.sock.close()
        check not r.ok
        check took >= 0.3
        check took < 5

    test "connection refused is a failed probe":
        let srv = startServer(proc (p: string, c: AsyncSocket) {.async.} = discard)
        let t = srv.target
        srv.sock.close()
        let r = waitFor httpRequest(t, "/")
        check not r.ok

    test "the engine through real HTTP drops a catch-all host and keeps real paths":
        let catchAll = startServer(proc (p: string, c: AsyncSocket) {.async.} =
            await c.send(status(200, "OK", body = "page".repeat(100))))
        let real = startServer(proc (p: string, c: AsyncSocket) {.async.} =
            if p == "/admin":
                await c.send(status(200, "OK", body = "secret"))
            else:
                await c.send(status(404, "Not Found")))
        let res = waitFor busDirectories(@[catchAll.target, real.target], @["/admin", "/other"],
            parseStatusFilter("200"), 0, 4)
        catchAll.sock.close()
        real.sock.close()
        check res[0].findings.len == 0
        check res[0].summary.suppressed == 2
        check res[1].findings.len == 1
        check res[1].findings[0].path == "/admin"
        check res[1].findings[0].size == 6
