import std/tables
import results
import modules/iputils

proc runDomains*(domains: seq[string], udpEnabled: bool,
                 process: proc (domain: string, index: int): DomainResult,
                 onError: proc (domain, msg: string)): seq[DomainResult] =
    ## Runs `process` for every domain in order. A failure is recorded as a dsError
    ## result and never stops the later domains.
    for i, domain in domains:
        var res: DomainResult
        try:
            res = process(domain, i)
        except CatchableError as e:
            res = DomainResult(domain: domain, status: dsError, error: e.msg,
                               udpEnabled: udpEnabled, ips: initTable[string, IPv4]())
            onError(domain, e.msg)
        result.add res
