# Module vhost
import std/[osproc, strformat, strutils, tables, asyncdispatch]
import iputils
import sfutils

proc getVHost(ip: string): Future[IPv4] {.async.} =
    let 
        command = fmt"nslookup {ip} | awk '/name = / {{print $4}}'"
        vhost = execCmdEx(command).output.strip(chars = {'.', ' ', '\n'})
    return newIPv4(ip, vhost)

proc getVHostTable*(subdomains: seq[Subdomain]): Table[string, IPv4] =
    var futures: seq[Future[IPv4]] = @[]
    for s in subdomains:
        for i in s.ipv4:
            futures.add(getVHost(i))
    var vhost: IPv4
    for i in futures:
        vhost = waitFor(i)
        result[vhost.ip] = vhost