import helpers
import std/[terminal, strutils, tables]
import modules/[iputils, subfinder]

proc printResults*(subdomains: seq[Subdomain], ips: Table[string, IPv4]) =
    printMsg(neutral, "[*] Printing results\n")
    for s in subdomains:
        styledEcho styleUnderscore, s.url
        if not s.isAlive:
            styledEcho "  ↳ ", fgRed, styleBright, styleUnderscore, "Public IPv4 not found\n"
            continue
        for ip in s.ipv4:
            styledEcho "  ↳ ", fgGreen, styleUnderscore, ip
            let
                vhostnames = ips[ip].vhostNames.join(", ")
                rdns = ips[ip].rdns
                ports = ips[ip].openPorts            
            if rdns == "":
                discard
            else:
                styledEcho "    ↳ ", styleBright, "Reverse DNS: ", resetStyle, rdns
            if vhostnames == "":
                discard
            else:
                styledEcho "    ↳ ", styleBright, "Virtual Hostnames: ", resetStyle, vhostnames
            if len(ports) == 0:
                discard
            else:
                styledEcho "    ↳ ", styleBright, "Open Ports: ", resetStyle, fgGreen, ports.join(", ")
            echo " "