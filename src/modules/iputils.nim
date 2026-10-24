# Module iputils
import std/[strutils]

type
    IPv4* = object
        ip*: string
        rdns*: string
        vhostNames*: seq[string]
        openPorts*: seq[int]
        udpOpenPorts*: seq[int]         # replied to a UDP probe
        udpOpenFilteredPorts*: seq[int] # no reply to a UDP probe

proc newIPv4*(ip: string, rdns: string = "", vhostNames: seq[string] = @[], openPorts: seq[int] = @[],
              udpOpenPorts: seq[int] = @[], udpOpenFilteredPorts: seq[int] = @[]): IPv4
    = IPv4(ip: ip, rdns: rdns, vhostnames: vhostNames, openPorts: openPorts,
           udpOpenPorts: udpOpenPorts, udpOpenFilteredPorts: udpOpenFilteredPorts)

proc addOpenPorts*(ip:IPv4, ports: seq[int]): IPv4 = 
    newIPv4(ip.ip, ip.rdns, ip.vhostNames, ports, ip.udpOpenPorts, ip.udpOpenFilteredPorts)

proc addUdpPorts*(ip: IPv4, open: seq[int], openFiltered: seq[int]): IPv4 =
    newIPv4(ip.ip, ip.rdns, ip.vhostNames, ip.openPorts, open, openFiltered)

proc isLoopBackIP*(ip: string): bool = ip.startsWith("127")