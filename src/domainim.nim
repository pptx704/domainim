import std/[parseopt, os, strformat, terminal, strutils]
import processors, helpers, results

let 
    usage = fmt"Invalid argument(s). Use ./{getAppFilename().extractFilename} --help for usage."
    banner = """

▓█████▄  ▒█████   ███▄ ▄███▓ ▄▄▄       ██▓ ███▄    █  ██▓ ███▄ ▄███▓
▒██▀ ██▌▒██▒  ██▒▓██▒▀█▀ ██▒▒████▄    ▓██▒ ██ ▀█   █ ▓██▒▓██▒▀█▀ ██▒
░██   █▌▒██░  ██▒▓██    ▓██░▒██  ▀█▄  ▒██▒▓██  ▀█ ██▒▒██▒▓██    ▓██░
░▓█▄   ▌▒██   ██░▒██    ▒██ ░██▄▄▄▄██ ░██░▓██▒  ▐▌██▒░██░▒██    ▒██ 
░▒████▓ ░ ████▓▒░▒██▒   ░██▒ ▓█   ▓██▒░██░▒██░   ▓██░░██░▒██▒   ░██▒
 ▒▒▓  ▒ ░ ▒░▒░▒░ ░ ▒░   ░  ░ ▒▒   ▓▒█░░▓  ░ ▒░   ▒ ▒ ░▓  ░ ▒░   ░  ░
 ░ ▒  ▒   ░ ▒ ▒░ ░  ░      ░  ▒   ▒▒ ░ ▒ ░░ ░░   ░ ▒░ ▒ ░░  ░      ░
 ░ ░  ░ ░ ░ ░ ▒  ░      ░     ░   ▒    ▒ ░   ░   ░ ░  ▒ ░░      ░   
   ░        ░ ░         ░         ░  ░ ░           ░  ░         ░   
 ░  

"""

proc startChecking(domain: string, portStr: string, dnsStr: string, sbList: string, rps: int, filename: string, forceBrute: bool) =
    var
        outfile: File
        writeable: bool = true
        ports: seq[int]
    try:
        ports = processPortString(portStr)
    except ValueError:
        echo "Invalid port specification. Example of proper form: 't10,5432,53,100-150'"
        return
    echo banner
    styledEcho "Provided domain: ", styleUnderscore, domain
    let dnsStr = processDnsString(dnsStr)

    let subdomains = processSubdomains(domain, dnsStr, sbList, rps, forceBrute)
    if len(subdomains) == 0:
        printMsg(error, fmt"[-] No subdomains found for {domain}. Aborting process.")
        return

    printPorts(portStr)
    var iptable = processVHostNames(subdomains, dnsStr)
    iptable = processOpenPorts(iptable, ports)

    if not filename.isEmptyOrWhitespace and not outfile.open(filename, fmWrite):
        printOutfile(false, filename)
        writeable = false

    if not filename.isEmptyOrWhitespace and writeable:
        printOutfile(true, filename)
        saveResults(subdomains, iptable, outfile)
        printUpdate(success, fmt"[+] Results saved to {filename}")
    else:
        printResults(subdomains, iptable)
    

proc main =
    var 
        ports = ""
        p = initOptParser(quoteShellCommand(commandLineParams()))
        domain: string
        dns = ""
        sbList = ""
        rps: int = 1024
        outfile = ""
        forceBrute = false
    if paramCount() == 0:
        echo usage
        return
    while true:
        p.next()
        case p.kind
        of cmdEnd: break
        of cmdArgument:
            if domain != "":
                echo usage
                return
            domain = p.key
        of cmdLongOption:
            case p.key
            of "ports":
                ports = p.val
            of "dns":
                dns = p.val
            of "wordlist":
                sbList = p.val
            of "rps":
                try:
                    rps = p.val.parseInt
                    if rps < 1: raise newException(ValueError, "rps must be positive")
                except ValueError:
                    echo usage
                    return
            of "force-brute":
                forceBrute = true
            of "out":
                if p.val.endsWith(".json"):
                    outfile = p.val
                else:
                    echo fmt"Invalid output filename {p.val}. File must be a json file."
                    return
            of "help":
                printHelp()
                return
            else:
                echo usage
                return
        of cmdShortOption:
            case p.key:
            of "p":
                ports = p.val
            of "d":
                dns = p.val
            of "l":
                sbList = p.val
            of "r":
                try:
                    rps = p.val.parseInt
                    if rps < 1: raise newException(ValueError, "rps must be positive")
                except ValueError:
                    echo usage
                    return
            of "f":
                forceBrute = true
            of "o":
                if p.val.endsWith(".json"):
                    outfile = p.val
                else:
                    echo fmt"Invalid output filename {p.val}. File must be a json file."
                    return
            of "h":
                printHelp()
                return
            else:
                echo usage
                return

    if domain.isEmptyOrWhitespace:
        echo usage
        return

    startChecking(domain.strip.toLowerAscii, ports, dns, sbList, rps, outfile, forceBrute)

when isMainModule:
    main()