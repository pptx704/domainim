# Pure helpers for target domain input. File reading is left to the caller.
import std/strutils

type TargetSet* = object
    valid*: seq[string]
    invalid*: seq[string]

proc normalizeDomain*(s: string): string =
    s.strip.toLowerAscii

proc isValidDomain*(s: string): bool =
    ## Expects a normalised name.
    if s.len == 0 or s.len > 253 or '.' notin s:
        return false
    for label in s.split('.'):
        if label.len == 0 or label.len > 63:
            return false
        if label[0] == '-' or label[^1] == '-':
            return false
        for c in label:
            if c notin {'a'..'z', '0'..'9', '-'}:
                return false
    return true

proc parseTargets*(inputs: seq[string]): TargetSet =
    ## Normalises and validates in input order; duplicates collapse.
    ## Invalid entries keep their original (stripped) text.
    for raw in inputs:
        let d = normalizeDomain(raw)
        if isValidDomain(d):
            if d notin result.valid:
                result.valid.add d
        else:
            result.invalid.add raw.strip

proc parseTargetFile*(content: string): seq[string] =
    ## One entry per line; blank lines and `#` comments are skipped.
    for line in content.splitLines:
        let l = line.strip
        if l.len == 0 or l.startsWith('#'):
            continue
        result.add l
