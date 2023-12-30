import std/[parseopt, os, strformat, terminal, strutils]
import processors, helpers, results

let 
    usage = fmt"Usage ./{getAppFilename().extractFilename} <domain> [--ports=<ports> | -p:ports] [--wordlist=<filename>] [--dns=<ip>[#port]] [--throttle=<int>]"
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

proc startChecking(domain: string, portStr: string, dnsStr: string, sbList: string, throttle: int) =
    var ports: seq[int]
    try:
        ports = processPortString(portStr)
    except:
        echo "Invalid port specification. Example of proper form: 't10,5432,53,100-150'"

    echo banner
    styledEcho "Provided domain: ", styleUnderscore, domain
    let subdomains = processSubdomains(domain, dnsStr, sbList, throttle)
    if len(subdomains) == 0:
        return
    var iptable = processVHostNames(subdomains)
    printPorts(portStr)
    iptable = processOpenPorts(iptable, ports)
    printResults(subdomains, iptable)
    

proc main =
    var 
        ports = ""
        p = initOptParser(quoteShellCommand(commandLineParams()))
        domain: string
        dns = ""
        sbList = ""
        throttle: int = 1000
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
            of "throttle":
                try:
                    throttle = p.val.parseInt
                except:
                    echo usage
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
            of "t":
                try:
                    throttle = p.val.parseInt
                except:
                    echo usage
                    return
            of "h":
                printHelp()
                return
            else:
                echo usage
                return
    startChecking(domain, ports, dns, sbList, throttle)

when isMainModule:
    main()