# Module vhost
import std/[osproc, strformat, strutils, tables]
import iputils, sfutils
import "../helpers"

proc getVHost(ip: string): IPv4 =
    let 
        command = fmt"nslookup {ip} | awk '/name = / {{print $4}}'"
        vhost = execCmdEx(command).output.strip(chars = {'.', ' ', '\n'})
    return newIPv4(ip, vhost)

proc getVHostTable*(subdomains: seq[Subdomain]): Table[string, IPv4] =
    var progress = 0
    for s in subdomains:
        for i in s.ipv4:
            result[i] = getVHost(i)
        progress += 1
        var pbar = (progress * 100 / len(subdomains)).toInt()
        updateProgress(pbar)