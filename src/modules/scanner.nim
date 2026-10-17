# module scanner

## TCP connect scanner. All hosts are scanned concurrently on a single async
## event loop with a bounded number of in-flight connection attempts.

import std/[asyncnet, asyncdispatch, net, random, tables, algorithm, times]
import scannerutils

const
    baseTimeout = 750 # ms, added to the measured latency of each host
    maxSockets = 4096 # concurrent connection attempts
    maxRate = 5000.0 # connection attempts per second. Bursts beyond that get SYNs
                     # dropped in local/router queues, which hides open ports

type
    ScanState = ref object
        hosts: seq[string]       # hosts that answered the ping
        timeouts: seq[int]       # per host connect timeout
        ports: seq[int]          # shuffled
        next, done, total: int
        nextSlot: float          # earliest time the next attempt may start
        open: seq[seq[int]]
        onProgress: proc(done, total: int)

randomize()

proc isOpen(ip: string, port: int, timeout: int): Future[bool] {.async.} =
    let sock = newAsyncSocket()
    try:
        result = await withTimeout(sock.connect(ip, port.Port), timeout)
    except CatchableError:
        result = false
    finally:
        try:
            sock.close()
        except CatchableError:
            discard

proc waitSlot(s: ScanState) {.async.} =
    ## Reserves the next free start time so attempts are spread at `maxRate`
    let
        now = epochTime()
        slot = max(s.nextSlot, now)
    s.nextSlot = slot + 1.0 / maxRate
    if slot - now >= 0.001:
        await sleepAsync(int((slot - now) * 1000))

proc worker(s: ScanState) {.async.} =
    ## Takes (host, port) pairs until none are left. Pairs are ordered port-major,
    ## so each host only gets a fraction of the concurrent attempts at a time.
    while s.next < s.total:
        let
            i = s.next
            h = i mod s.hosts.len
            port = s.ports[i div s.hosts.len]
        inc(s.next)
        await waitSlot(s)
        if await isOpen(s.hosts[h], port, s.timeouts[h]):
            s.open[h].add(port)
        inc(s.done)
        if s.onProgress != nil:
            s.onProgress(s.done, s.total)

proc scanHosts*(hosts: seq[string], targetPorts: seq[int],
                onProgress: proc(done, total: int) = nil): Table[string, seq[int]] =
    ## Returns the open ports of every host. Hosts that don't answer ping are
    ## not scanned and have no open ports.
    let s = ScanState(ports: targetPorts, onProgress: onProgress)
    shuffle(s.ports)
    for host, ms in measureLatencies(hosts):
        result[host] = @[]
        if ms >= 0:
            s.hosts.add(host)
            s.timeouts.add(baseTimeout + ms)
    if s.hosts.len == 0 or s.ports.len == 0:
        return

    s.open = newSeq[seq[int]](s.hosts.len)
    s.total = s.hosts.len * s.ports.len
    var workers: seq[Future[void]]
    for _ in 1..min(maxSockets, s.total):
        workers.add(worker(s))
    waitFor all(workers)

    for h, host in s.hosts:
        result[host] = s.open[h].sorted
