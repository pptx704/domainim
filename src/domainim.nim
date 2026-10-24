import std/[parseopt, os, strformat, terminal, strutils]
import processors, helpers, results, targets

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

proc startChecking(domains: seq[string], portStr: string, dnsStr: string, sbList: string, rps: int, filename: string, forceBrute: bool, udpPortStr: string = "") =
    var
        outfile: File
        writeable: bool = true
        ports: seq[int]
        udpPorts: seq[int]
    try:
        ports = processPortString(portStr)
    except ValueError:
        echo "Invalid port specification. Example of proper form: 't10,5432,53,100-150'"
        return
    try:
        udpPorts = processPortString(udpPortStr)
    except ValueError:
        echo "Invalid UDP port specification. Example of proper form: 't10,53,100-150'"
        return
    let
        udpEnabled = udpPorts.len > 0
        domain = domains[0]
    echo banner
    styledEcho "Provided domain: ", styleUnderscore, domain
    let dnsStr = processDnsString(dnsStr)

    let subdomains = processSubdomains(domain, dnsStr, sbList, rps, forceBrute)
    if len(subdomains) == 0:
        printMsg(error, fmt"[-] No subdomains found for {domain}. Aborting process.")
        return

    printPorts(portStr)
    if udpEnabled:
        printUdpPorts(udpPortStr)
    var iptable = processVHostNames(subdomains, dnsStr)
    iptable = processOpenPorts(iptable, ports)
    if udpEnabled:
        iptable = processOpenUdpPorts(iptable, udpPorts)

    if not filename.isEmptyOrWhitespace and not outfile.open(filename, fmWrite):
        printOutfile(false, filename)
        writeable = false

    if not filename.isEmptyOrWhitespace and writeable:
        printOutfile(true, filename)
        saveResults(subdomains, iptable, outfile, udpEnabled)
        printUpdate(success, fmt"[+] Results saved to {filename}")
    else:
        printResults(subdomains, iptable, udpEnabled)
    

proc main =
    var 
        ports = ""
        udpPorts = ""
        p = initOptParser(quoteShellCommand(commandLineParams()))
        domains: seq[string]
        listFile = ""
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
            domains.add p.key
        of cmdLongOption:
            case p.key
            of "ports":
                ports = p.val
            of "udp-ports":
                udpPorts = p.val
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
            of "list":
                listFile = p.val
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
            of "i":
                listFile = p.val
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

    if listFile != "":
        try:
            domains.add parseTargetFile(readFile(listFile))
        except IOError, OSError:
            echo fmt"Could not read list file {listFile}."
            return

    let targets = parseTargets(domains)
    for bad in targets.invalid:
        echo fmt"Invalid domain '{bad}'. It will be skipped."
    if targets.valid.len == 0:
        echo usage
        return

    startChecking(targets.valid, ports, dns, sbList, rps, outfile, forceBrute, udpPorts)

when isMainModule:
    main()