import std/[parseopt, os, strformat, terminal, strutils]
import processors, helpers, results, targets, runner
import modules/dirbuster

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

proc startChecking(domains: seq[string], portStr: string, dnsStr: string, sbList: string, rps: int, filename: string, forceBrute: bool, udpPortStr: string = "", dirOpts: DirOptions = DirOptions()) =
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
    let udpEnabled = udpPorts.len > 0
    var
        results: seq[DomainResult]
        resolver = dnsStr
    echo banner
    proc processDomain(domain: string, i: int): DomainResult =
        if domains.len > 1:
            printMsg(neutral, domainHeader(domain, i + 1, domains.len))
        styledEcho "Provided domain: ", styleUnderscore, domain
        if i == 0:
            resolver = processDnsString(dnsStr)
        result = DomainResult(domain: domain, status: dsOk, udpEnabled: udpEnabled, dirEnabled: dirOpts.enabled)
        result.subdomains = processSubdomains(domain, resolver, sbList, rps, forceBrute)
        if len(result.subdomains) == 0:
            result.status = dsNoSubdomains
            printMsg(error, fmt"[-] No subdomains found for {domain}. Aborting process.")
        else:
            printPorts(portStr)
            if udpEnabled:
                printUdpPorts(udpPortStr)
            var iptable = processVHostNames(result.subdomains, resolver)
            iptable = processOpenPorts(iptable, ports)
            if udpEnabled:
                iptable = processOpenUdpPorts(iptable, udpPorts)
            result.ips = iptable
            if dirOpts.enabled:
                try:
                    result.dirResults = processDirectories(result.subdomains, dirOpts)
                except CatchableError as e:
                    printMsg(error, fmt"[!] Directory busting failed for {domain}: {e.msg}")
    results = runDomains(domains, udpEnabled, processDomain,
        proc (domain, msg: string) = printMsg(error, fmt"[!] Failed to process {domain}: {msg}"))

    if not filename.isEmptyOrWhitespace and not outfile.open(filename, fmWrite):
        printOutfile(false, filename)
        writeable = false

    if not filename.isEmptyOrWhitespace and writeable:
        printOutfile(true, filename)
        saveDomainResults(results, outfile)
        outfile.close()
        printUpdate(success, fmt"[+] Results saved to {filename}")
    elif results.len > 1 or results[0].status == dsOk:
        printDomainResults(results)

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
        dirWordlist = ""
        dirWordlistGiven = false
        dirOptionGiven = false
        dirStatus = "200,204,301,302,307,308,401,403"
        dirRps = "50"
        dirConcurrency = "20"
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
            of "dir-wordlist":
                dirWordlist = p.val
                dirWordlistGiven = true
            of "dir-status":
                dirStatus = p.val
                dirOptionGiven = true
            of "dir-rps":
                dirRps = p.val
                dirOptionGiven = true
            of "dir-concurrency":
                dirConcurrency = p.val
                dirOptionGiven = true
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

    var dirOpts: DirOptions
    if dirWordlistGiven or dirOptionGiven:
        if not dirWordlistGiven:
            echo "The --dir-status, --dir-rps and --dir-concurrency options need --dir-wordlist."
            return
        try:
            dirOpts.paths = parseWordlist(readFile(dirWordlist))
        except IOError, OSError:
            echo fmt"Could not read directory wordlist {dirWordlist}."
            return
        except ValueError as e:
            echo fmt"Invalid directory wordlist {dirWordlist}: {e.msg}."
            return
        try:
            dirOpts.filter = parseStatusFilter(dirStatus)
        except ValueError:
            echo fmt"Invalid --dir-status '{dirStatus}'. Example of proper form: '200,301-303,403'"
            return
        try:
            dirOpts.rps = dirRps.parseInt
            dirOpts.concurrency = dirConcurrency.parseInt
            if dirOpts.rps < 1 or dirOpts.concurrency < 1:
                raise newException(ValueError, "must be positive")
        except ValueError:
            echo "Invalid --dir-rps or --dir-concurrency. Both must be positive integers."
            return
        dirOpts.enabled = true

    let targets = parseTargets(domains)
    for bad in targets.invalid:
        echo fmt"Invalid domain '{bad}'. It will be skipped."
    if targets.valid.len == 0:
        echo usage
        return

    startChecking(targets.valid, ports, dns, sbList, rps, outfile, forceBrute, udpPorts, dirOpts)

when isMainModule:
    main()