# Module helper
import std/[terminal, tables, strutils]
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
            var vhostnames = ips[ip].vhostNames.join(", ")
            var rdns = ips[ip].rdns
            if rdns == "" or vhostnames == "":
                echo ""
                continue
            styledEcho "    ↳ ", styleBright, "Reverse DNS: ", resetStyle, rdns
            styledEcho "    ↳ ", styleBright, "Virtual Hostnames: ", resetStyle, vhostnames
            # Add open ports
            echo " "

proc startProgress*() =
    var msg = "    Progress: " & "░".repeat(20)
    printMsg(info, msg)

proc updateProgress*(progress: int) =
    let prog = min(20, (progress/5).toInt)
    var msg = "    Progress: " & "█".repeat(prog) & "░".repeat(20 - prog) & " $1%" % $progress
    printUpdate(info, msg)

proc finishProgress*(msg: string) =
    clearLast()
    printUpdate(success, msg)