import std/[unittest, asyncdispatch, asyncnet, nativesockets, net, tables]
import ../src/modules/udpscanner

const loopback = "127.0.0.1"

proc bindUdp(): (Socket, int) =
    let s = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    s.bindAddr(Port(0), loopback)
    (s, s.getLocalAddr()[1].int)

proc bindAsyncUdp(): (AsyncSocket, int) =
    let s = newAsyncSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP, buffered = false)
    s.bindAddr(Port(0), loopback)
    (s, s.getLocalAddr()[1].int)

proc echoOnce(s: AsyncSocket, times: int) {.async.} =
    ## Answers `times` datagrams on the dispatcher that the scanner drives
    for _ in 1..times:
        let (_, host, port) = await s.recvFrom(2048)
        await s.sendTo(host, port, "pong")

proc unusedPort(): int =
    # bind then close: nothing listens afterwards, so the kernel answers with ICMP unreachable
    let (s, p) = bindUdp()
    s.close()
    p

suite "classify":
    test "every event maps to a state":
        check classify(ueReply) == usOpen
        check classify(ueRefused) == usClosed
        check classify(ueTimeout) == usOpenFiltered
        check classify(ueError) == usOpenFiltered

    test "only a reply is open":
        for e in UdpEvent:
            check (classify(e) == usOpen) == (e == ueReply)

suite "probePayload":
    test "known services get a protocol probe, others an empty datagram":
        for p in [53, 123, 161, 137, 1900, 5353]:
            check probePayload(p).len > 0
        check probePayload(9999) == ""
        check probePayload(53) != probePayload(123)

suite "loopback scan":
    test "a socket that answers is open":
        let (s, port) = bindAsyncUdp()
        defer: s.close()
        asyncCheck echoOnce(s, 2)
        check waitFor(probe(loopback, port, 2000)) == usOpen
        let res = scanUdpHosts(@[loopback], @[port])
        check res[loopback].open == @[port]
        check res[loopback].openFiltered.len == 0

    test "a silent socket is open|filtered, not open":
        let (s, port) = bindUdp()
        defer: s.close()
        let st = waitFor probe(loopback, port, 300)
        check st == usOpenFiltered
        let res = scanUdpHosts(@[loopback], @[port])
        check res[loopback].open.len == 0
        check res[loopback].openFiltered == @[port]

    test "an unused port is closed":
        let port = unusedPort()
        let st = waitFor probe(loopback, port, 2000)
        if st != usClosed:
            skip()  # this platform does not report ICMP port unreachable on loopback
        else:
            let res = scanUdpHosts(@[loopback], @[port])
            check res[loopback].open.len == 0
            check res[loopback].openFiltered.len == 0

    test "mixed ports are sorted into the right lists":
        let (silent, silentPort) = bindUdp()
        defer: silent.close()
        let (echo, echoPort) = bindAsyncUdp()
        defer: echo.close()
        asyncCheck echoOnce(echo, 1)
        let res = scanUdpHosts(@[loopback], @[echoPort, silentPort, echoPort])
        check res[loopback].open == @[echoPort]
        check res[loopback].openFiltered == @[silentPort]

    test "no ports or no hosts scan nothing":
        check scanUdpHosts(@[loopback], @[])[loopback].open.len == 0
        check scanUdpHosts(@[], @[53]).len == 0

    test "duplicate hosts are probed once":
        let (s, port) = bindUdp()
        defer: s.close()
        let res = scanUdpHosts(@[loopback, loopback], @[port])
        check res.len == 1
        check res[loopback].openFiltered == @[port]

    test "progress reaches the total":
        let (s, port) = bindUdp()
        defer: s.close()
        var last = 0
        var total = 0
        discard scanUdpHosts(@[loopback], @[port], proc(done, t: int) =
            last = done
            total = t)
        check last == 1
        check total == 1
