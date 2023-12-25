# Module iputils
import std/[strutils]

type
    IPv4* = object
        ip*: string
        vhostName*: string
        openPorts*: seq[int]

proc newIPv4*(ip: string, vhostName: string = "", openPorts: seq[int] = @[]): IPv4 
    = IPv4(ip: ip, vhostname: vhostname, openPorts: openPorts)

proc isLoopBackIP*(ip: string): bool = ip.startsWith("127")