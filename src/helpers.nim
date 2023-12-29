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

proc startProgress*() =
    var msg = "    Progress: " & "░".repeat(20)
    printMsg(info, msg)

proc updateProgress*(progress: int, msg: string = "") =
    let prog = min(20, (progress/5).toInt)
    var msg = "    Progress: " & "█".repeat(prog) & "░".repeat(20 - prog) & " $1%" % $progress & msg
    printUpdate(info, msg)

proc finishProgress*(msg: string) =
    clearLast()
    printUpdate(success, msg)

proc printPorts*(portStr: string) =
    if portStr == "all":
        printMsg(neutral, "[*] All ports are being scanned. This will take some times.")
    elif portStr == "none":
        printMsg(neutral, "[*] Port scanning is turened off.")
    elif portStr == "":
        printMsg(neutral, "[*] Port specification not provided. Port scanning will be skipped.")