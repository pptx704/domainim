# module scanner

import std/[strutils, asyncnet, asyncdispatch, net, nativesockets, random, sequtils, os]
import scannerutils

var
    openPorts: array[1..65535, int]
    countOpen = 0
    timeout = 750
    maxThreads = 2
    toScan = 0
    fileDesc = 1024
    division = (65535/fileDesc).toInt

randomize()

proc connect(ip: string, port: int) {.async.} =
    var sock = newAsyncSocket()
    try:
        if await withTimeout(sock.connect(ip, port.Port), timeout):
            openPorts[port] = port
            inc countOpen
    except:
        discard
    finally:
        try:
            sock.close()
        except:
            discard

proc scan(ip: cstring, port_seq: seq[int]) {.async.} =
    for dist in port_seq.distribute(max(1, (port_seq.len / fileDesc).toInt)):
        var sockops = newseq[Future[void]](port_seq.len)
        for i in low(dist)..high(dist):
            sockops[i] = connect($ip, port_seq[i])
        waitFor all(sockops)
   
proc scannerThread(supSocket: SuperSocket) {.thread.} =
    var
        host = supSocket.IP
        port_seq = supSocket.ports

    shuffle(port_seq) ## Shuffle ports ordere
    waitFor scan(host, port_seq)


proc scanPorts*(host: string, targetPorts: seq[int]): seq[int] =
    var 
        thr: seq[Thread[SuperSocket]] = newSeq[Thread[SuperSocket]](maxThreads)
        ip: string
        ms: int
    division = max(1, (targetPorts.len/fileDesc).toInt)
    ip = host
    
    for p in targetPorts:
        openPorts[p] = -1

    ms = measureLatency(ip)
    if ms == -1:
        return
    else:
        timeout = timeout + ms
    
    toScan = targetPorts.len

    for ports in targetPorts.distribute(division):
        ## Start scanning
        block current_ports:
            while true:
                for i in low(thr)..high(thr):
                    if not thr[i].running:
                        let supSocket = SuperSocket(IP: cstring(ip), ports: ports)
                        createThread(thr[i], scannerThread, supSocket)
                        break current_ports   
                sleep(1)

    thr.joinThreads()

    for i in 1..65535:
        if openPorts[i] == i:
            result.add(i)

    for i in 1..65535:
        openPorts[i] = 0
    countOpen = 0