# Module iputils
import std/[strutils, osproc]
import regex

type
    IPv4* = object
        ip*: string
        rdns*: string
        vhostNames*: seq[string]
        openPorts*: seq[int]
    
    SuperSocket* = object
        IP*: cstring
        ports*: seq[int]

proc newIPv4*(ip: string, rdns: string = "", vhostNames: seq[string] = @[], openPorts: seq[int] = @[]): IPv4 
    = IPv4(ip: ip, rdns: rdns, vhostnames: vhostNames, openPorts: openPorts)

proc addOpenPorts*(ip:IPv4, ports: seq[int]): IPv4 = 
    newIPv4(ip.ip, ip.rdns, ip.vhostNames, ports)

proc isLoopBackIP*(ip: string): bool = ip.startsWith("127")

proc measureLatency*(ip: string): int =
    var 
        outp: string
        errC: int
        reg: RegexMatch2
    (outp, errC) = execCmdEx("ping $1 -c 1" % [ip])
    if outp.find(re2"time[<=]([\d\.]+).+ms", reg):
        result = outp[reg.group(0)].parseFloat().toInt()
    else:
        result = -1