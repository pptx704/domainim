# Module helper
import std/[terminal, tables]
import modules/[sfutils, iputils]

type MsgType* = enum
    info, success, error, neutral


proc clearLast() = 
    cursorUp 1
    eraseLine()

proc printMsg*(msgtype: MsgType, msg: string) =
    case msgtype
    of info:
        styledEcho fgYellow, msg
    of success:
        styledEcho fgGreen, msg
    of error:
        styledEcho fgRed, msg
    of neutral:
        styledEcho fgMagenta, msg

proc printUpdate* (msgtype: MsgType, msg: string) =
    clearLast()
    printMsg(msgtype, msg)

proc printResults*(subdomains: seq[Subdomain], ips: Table[string, IPv4]) =
    printMsg(neutral, "\n[*] Printing results\n")
    for s in subdomains:
        styledEcho styleUnderscore, s.url
        if not s.isAlive:
            styledEcho "  ↳ ", fgRed, styleBright, styleUnderscore, "Public IPv4 not found\n"
            continue
        for ip in s.ipv4:
            styledEcho "  ↳ ", fgGreen, styleUnderscore, ip
            var vhostname = ips[ip].vhostName
            if vhostname == "":
                echo ""
                continue
            styledEcho "    ↳ ", styleBright, "Hostname: ", resetStyle, vhostname
            # Add open ports
            echo " "