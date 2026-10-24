# Module iputils
import std/[strutils, net]

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

proc canonicalIPv6*(ip: string): string =
    ## Returns the compressed lowercase form of an IPv6 address, or "" when `ip` is
    ## invalid, unspecified, loopback, link-local (fe80::/10) or IPv4-mapped.
    var addr6: IpAddress
    try:
        addr6 = parseIpAddress(ip.strip())
    except ValueError:
        return ""
    if addr6.family != IpAddressFamily.IPv6:
        return ""
    let b = addr6.address_v6
    var allZero = true
    for i in 0..14:
        if b[i] != 0:
            allZero = false
            break
    if allZero and (b[15] == 0 or b[15] == 1):
        return ""
    if b[0] == 0xfe and (b[1] and 0xc0) == 0x80:
        return ""
    var mapped = true
    for i in 0..9:
        if b[i] != 0:
            mapped = false
            break
    if mapped and b[10] == 0xff and b[11] == 0xff:
        return ""
    return $addr6
