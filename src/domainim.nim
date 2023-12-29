import std/[parseopt, os, strformat, terminal]
import processors, helpers

let 
    usage = fmt"Usage ./{getAppFilename().extractFilename} <domain> [--ports=<ports>]"
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

proc startChecking(domain: string, portStr: string, dnsStr: string) =
    var ports: seq[int]
    try:
        ports = processPortString(portStr)
    except:
        echo "Invalid port specification. Example of proper form: 't10,5432,53,100-150'"

    echo banner
    styledEcho "Provided domain: ", styleUnderscore, domain
    let subdomains = processSubdomains(domain)
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
            else:
                echo usage
                return
        else:
            echo usage
            return
    startChecking(domain, ports, dns)

when isMainModule:
    main()