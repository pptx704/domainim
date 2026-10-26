# Module helper
import std/[terminal, strutils, os, strformat]

type MsgType* = enum
    info, success, error, neutral


proc clearLast*() = 
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

proc startProgress*() =
    var msg = "    Progress: " & "░".repeat(20)
    printMsg(info, msg)

proc updateProgress*(current, total: int, msg: string = "") =
    let 
        progress = (current * 100 / total).toInt
        prog = min(20, (progress/5).toInt)
        msg = "    Progress: " & "█".repeat(prog) & "░".repeat(20 - prog) & " $1%" % $progress & msg
    printUpdate(info, msg)

proc finishProgress*(msg: string) =
    clearLast()
    printUpdate(success, msg)

proc printPorts*(portStr: string) =
    if portStr == "all":
        printMsg(neutral, "[*] All ports are being scanned. This will take some time.")
    elif portStr == "none":
        printMsg(neutral, "[*] Port scanning is turned off.")
    elif portStr == "":
        printMsg(neutral, "[*] Port specification not provided. Port scanning will be skipped.")

proc printUdpPorts*(portStr: string) =
    if portStr == "all":
        printMsg(neutral, "[*] All UDP ports are being scanned. This will take some time.")
    else:
        printMsg(neutral, "[*] UDP port scanning is turned on.")

proc printOutfile*(status: bool, filename: string) =
    if status:
        printMsg(info, fmt"[*] Writing results to {filename}.")
    else:
        printMsg(error, fmt"[!] Could not open {filename}. Results will be printed on console.")

proc printHelp*() =
    echo """
Usage:
    $1 <domain>... [--list=<filename> | -i:<filename>] [--ports=<ports> | -p:<ports>] [--udp-ports=<ports>] [--wordlist=<filename> | -l:<filename> [--rps=<int> | -r:<int>] [--force-brute | -f]] [--dns=<dns> | -d:<dns>] [--out=<filename> | -o:<filename>] [--dir-wordlist=<filename> [--dir-status=<list>] [--dir-rps=<int>] [--dir-concurrency=<int>]]
    $1 (-h | --help)

Options:
    -h, --help              Show this screen.
    -i, --list              File with target domains, one per line. Blank lines and lines starting with `#` are ignored.
                            Combines with domains given as arguments. Duplicates are removed.
    -p, --ports             Ports to scan. [default: `none`]
                            Can be `all`, `none`, `t<n>`, single value, range value, combination
    --udp-ports             UDP ports to scan. Same format as --ports. [default: `none`]
                            Replies are reported as open, silence as open|filtered.
    -l, --wordlist          Wordlist for subdomain bruteforcing. Bruteforcing is skipped for invalid file.
    -f, --force-brute       Bruteforce even if a wildcard record is found. Results resolving only to wildcard IPs are discarded.
    -d, --dns               IP and Port for DNS Resolver. Should be a valid IPv4 with an optional port [default: system default]
    -r, --rps               DNS queries to be made per second [default: 1024 req/s]
    --dir-wordlist          Wordlist of paths for directory busting on http and https of every resolved subdomain. Enables the feature.
    --dir-status            Status codes to report, a list of values and ranges [default: `200,204,301,302,307,308,401,403`]
    --dir-rps               Directory busting requests to be made per second [default: 50 req/s]
    --dir-concurrency       Directory busting requests in flight at once [default: 20]
    -o, --out               JSON file where the output will be saved. Filename must end with `.json`

Examples:
    $1 domainim.com --ports=80 --udp-ports=53,123
    $1 domainim.com domainim.org --list=targets.txt
    $1 domainim.com -p:t500 -l:wordlist.txt --dns:1.1.1.1#53 --out=results.json
    $1 domainim.com --dir-wordlist=paths.txt --dir-status=200,301-303 --dir-rps=20 --dir-concurrency=10
    $1 sub.domainim.com --ports=all --dns:8.8.8.8 -l:wordlist.txt -r:1500 -f -o:results.json""" % getAppFilename().extractFilename