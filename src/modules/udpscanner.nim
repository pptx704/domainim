# module udpscanner

## UDP scanner using connected datagram sockets, so no raw sockets or root are
## needed. A reply means open. An ICMP port unreachable on a connected socket
## surfaces as ECONNREFUSED and means closed. Silence means open|filtered.
## Hosts are scanned concurrently on a single async event loop with a bounded
## number of in-flight probes.

from std/posix import ECONNREFUSED, EAGAIN, EWOULDBLOCK, send, recv
import std/[asyncnet, asyncdispatch, net, nativesockets, os, random, tables, algorithm, times, sets, sequtils]

const
    probeTimeout = 1000 # ms to wait for a reply
    pollInterval = 20   # ms between checks of a socket for a reply
    maxSockets = 1024   # concurrent probes
    maxRate = 2000.0    # probes per second

type
    UdpEvent* = enum
        ueReply, ueRefused, ueTimeout, ueError

    UdpState* = enum
        usOpen, usClosed, usOpenFiltered

    UdpResult* = object
        open*: seq[int]          # answered the probe
        openFiltered*: seq[int]  # no answer, or no usable answer

    ScanState = ref object
        hosts: seq[string]
        ports: seq[int]          # shuffled
        next, done, total: int
        nextSlot: float
        res: seq[UdpResult]
        onProgress: proc(done, total: int)

proc bytes(s: varargs[int]): string =
    for b in s:
        result.add(char(b))

let
    dnsProbe = bytes(0x12, 0x34, 0x01, 0x00, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 1) # NS query for "."
    ntpProbe = bytes(0x1b) & newString(47)                                          # NTP client request
    snmpProbe = bytes(0x30, 0x29, 0x02, 0x01, 0x00, 0x04, 0x06) & "public" &
        bytes(0xa0, 0x1c, 0x02, 0x04, 0, 0, 0, 1, 0x02, 0x01, 0x00, 0x02, 0x01, 0x00,
              0x30, 0x0e, 0x30, 0x0c, 0x06, 0x08, 0x2b, 0x06, 0x01, 0x02, 0x01, 0x01, 0x01, 0x00,
              0x05, 0x00)                                                           # SNMPv1 get sysDescr
    netbiosProbe = bytes(0x80, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0x20) &
        "CKAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" & bytes(0, 0, 0x21, 0, 1)                 # node status
    ssdpProbe = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\n" &
        "MAN: \"ssdp:discover\"\r\nMX: 1\r\nST: ssdp:all\r\n\r\n"
    mdnsProbe = bytes(0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0) &
        bytes(9) & "_services" & bytes(7) & "_dns-sd" & bytes(4) & "_udp" & bytes(5) & "local" &
        bytes(0, 0, 0x0c, 0, 1)                                                     # PTR query

proc probePayload*(port: int): string =
    ## Protocol specific probe for common ports, an empty datagram otherwise
    case port
    of 53: dnsProbe
    of 123: ntpProbe
    of 161: snmpProbe
    of 137: netbiosProbe
    of 1900: ssdpProbe
    of 5353: mdnsProbe
    else: ""

proc classify*(event: UdpEvent): UdpState =
    case event
    of ueReply: usOpen
    of ueRefused: usClosed
    of ueTimeout, ueError: usOpenFiltered

proc probeEvent(ip: string, port: int, timeout: int): Future[UdpEvent] {.async.} =
    let sock = newAsyncSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP, buffered = false)
    try:
        await sock.connect(ip, port.Port)
        let payload = probePayload(port)
        if payload.len == 0:
            # an empty datagram needs the raw send, async send rejects zero length
            if send(sock.getFd, nil, 0, 0.cint) < 0:
                raiseOSError(osLastError())
        else:
            await sock.send(payload)
        # The dispatcher clears the pending ICMP error before waking a reader, and
        # the async recv never wakes for it, so poll the non-blocking socket.
        let deadline = epochTime() + timeout / 1000
        result = ueTimeout
        var buf: array[2048, char]
        while epochTime() < deadline:
            if recv(sock.getFd, addr buf[0], buf.len, 0.cint) >= 0:
                result = ueReply
                break
            let err = osLastError().int32
            if err == ECONNREFUSED:
                result = ueRefused
                break
            if err != EAGAIN and err != EWOULDBLOCK:
                result = ueError
                break
            await sleepAsync(pollInterval)
    except CatchableError:
        result = ueError
    finally:
        try:
            sock.close()
        except CatchableError:
            discard

proc probe*(ip: string, port: int, timeout: int = probeTimeout): Future[UdpState] {.async.} =
    ## State of a single UDP port
    result = classify(await probeEvent(ip, port, timeout))

proc waitSlot(s: ScanState) {.async.} =
    let
        now = epochTime()
        slot = max(s.nextSlot, now)
    s.nextSlot = slot + 1.0 / maxRate
    if slot - now >= 0.001:
        await sleepAsync(int((slot - now) * 1000))

proc worker(s: ScanState) {.async.} =
    while s.next < s.total:
        let
            i = s.next
            h = i mod s.hosts.len
            port = s.ports[i div s.hosts.len]
        inc(s.next)
        await waitSlot(s)
        case await probe(s.hosts[h], port)
        of usOpen: s.res[h].open.add(port)
        of usOpenFiltered: s.res[h].openFiltered.add(port)
        of usClosed: discard
        inc(s.done)
        if s.onProgress != nil:
            s.onProgress(s.done, s.total)

proc scanUdpHosts*(hosts: seq[string], targetPorts: seq[int],
                   onProgress: proc(done, total: int) = nil): Table[string, UdpResult] =
    ## Returns the confirmed open and the open|filtered UDP ports of every host.
    ## Hosts are not required to answer ping. Each (host, port) is probed once.
    let s = ScanState(ports: targetPorts.toHashSet.toSeq, onProgress: onProgress)
    shuffle(s.ports)
    for host in hosts:
        if host notin result:
            result[host] = UdpResult()
            s.hosts.add(host)
    if s.hosts.len == 0 or s.ports.len == 0:
        return

    s.res = newSeq[UdpResult](s.hosts.len)
    s.total = s.hosts.len * s.ports.len
    var workers: seq[Future[void]]
    for _ in 1..min(maxSockets, s.total):
        workers.add(worker(s))
    waitFor all(workers)

    for h, host in s.hosts:
        result[host] = UdpResult(open: s.res[h].open.sorted, openFiltered: s.res[h].openFiltered.sorted)
