# Module iputils
import std/[strutils]

type
    IPv4* = object
        ip*: string
        rdns*: string
        vhostNames*: seq[string]
        openPorts*: seq[int]

proc newIPv4*(ip: string, rdns: string = "", vhostNames: seq[string] = @[], openPorts: seq[int] = @[]): IPv4 
    = IPv4(ip: ip, rdns: rdns, vhostnames: vhostNames, openPorts: openPorts)

proc isLoopBackIP*(ip: string): bool = ip.startsWith("127")