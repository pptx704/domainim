import std/[unittest, asyncdispatch, strutils, tables, sets, times, algorithm]
import ../src/modules/dirbuster

# Pure parts

suite "wordlist parsing":
    test "comments, blanks, slashes and duplicates":
        let text = "# comment\n\nadmin\n/admin\n  login  \r\n/a/b/\n#x\nlogin\n"
        check parseWordlist(text) == @["/admin", "/login", "/a/b/"]

    test "empty wordlists raise":
        expect ValueError: discard parseWordlist("")
        expect ValueError: discard parseWordlist("# only\n\n  \n")

suite "status filter parsing":
    test "single code, list and ranges":
        let f = parseStatusFilter("200,301-303, 403")
        for c in [200, 301, 302, 303, 403]:
            check c in f
        for c in [201, 300, 304, 404]:
            check c notin f
        check 204 in parseStatusFilter("204")

    test "invalid specifications raise":
        for spec in ["", "abc", "99", "600", "300-200", "1-2-3", "200,", "200-"]:
            expect ValueError: discard parseStatusFilter(spec)

# Soft-404 baseline through the scheduler with a fake request proc

type
    Answer = proc (path: string, probe: int): ProbeResult
    Recorder = ref object
        requests: seq[string]

proc resp(status, size: int, location = ""): ProbeResult =
    ProbeResult(ok: true, status: status, size: size, location: location)

let target = DirTarget(hostname: "t.test", scheme: "http")
const allStatuses = "200,301,302,403,404"

proc runBaseline(paths: seq[string], answer: Answer, rec: Recorder = nil): DirResult =
    ## `probe` is the index of the baseline probe, -1 for a wordlist path
    var probes = 0
    let wordlist = paths.toHashSet
    let req = proc (t: DirTarget, path: string): Future[ProbeResult] {.async.} =
        if not rec.isNil:
            rec.requests.add(path)
        if path in wordlist:
            return answer(path, -1)
        inc probes
        return answer(path, probes)
    result = waitFor(busDirectories(@[target], paths, parseStatusFilter(allStatuses), 0, 4, req))[0]

proc findingPaths(r: DirResult): seq[string] =
    for f in r.findings:
        result.add(f.path)

suite "soft-404 baseline":
    test "(a) both probes fail: unreachable and nothing else requested":
        let rec = Recorder()
        let r = runBaseline(@["/a", "/b"], proc (p: string, n: int): ProbeResult = ProbeResult(), rec)
        check r.summary.unreachable
        check r.summary.baseline == bkUnreachable
        check r.findings.len == 0
        check rec.requests.len == 2
        check "/a" notin rec.requests and "/b" notin rec.requests

    test "(b) one probe fails: the other is the baseline":
        let r = runBaseline(@["/same", "/other"], proc (p: string, n: int): ProbeResult =
            if n == 1: ProbeResult()
            elif n > 0: resp(200, 1000)
            elif p == "/same": resp(200, 1005)
            else: resp(200, 9000))
        check not r.summary.unreachable
        check r.summary.baseline == bkStable
        check findingPaths(r) == @["/other"]
        check r.summary.suppressed == 1

    test "(c) both 404: nothing is filtered":
        let r = runBaseline(@["/a", "/b"], proc (p: string, n: int): ProbeResult =
            if n > 0: resp(404, 300)
            elif p == "/a": resp(200, 300)
            else: resp(404, 300))
        check r.summary.baseline == bkNotFound
        check findingPaths(r) == @["/a", "/b"]
        check r.summary.suppressed == 0

    test "(d) same non-404 status: size and redirect target decide":
        let paths = @["/admin", "/near", "/far", "/forbidden"]
        let r = runBaseline(paths, proc (p: string, n: int): ProbeResult =
            if n > 0: return resp(200, 1000 + n * 10)
            case p
            of "/admin": resp(200, 1000)
            of "/near": resp(200, 1030)
            of "/far": resp(200, 5000)
            else: resp(403, 1000))
        check r.summary.baseline == bkStable
        check findingPaths(r) == @["/far", "/forbidden"]
        check r.summary.suppressed == 2

    test "(d) redirects: same target dropped, different target kept":
        let r = runBaseline(@["/admin", "/panel", "/x"], proc (p: string, n: int): ProbeResult =
            if n > 0: return resp(301, 0, "/login?next=" & p)
            case p
            of "/admin": resp(301, 0, "/login?next=/admin")
            of "/panel": resp(301, 0, "/elsewhere")
            else: resp(301, 0, "/login?next=/x"))
        check r.summary.baseline == bkStable
        check findingPaths(r) == @["/panel"]
        check r.findings[0].redirect == "/elsewhere"
        check r.summary.suppressed == 2

    test "(e) different statuses: matches drop only on status and size":
        let paths = @["/a", "/b", "/c", "/d", "/e"]
        let r = runBaseline(paths, proc (p: string, n: int): ProbeResult =
            if n == 1: return resp(200, 1000)
            if n == 2: return resp(403, 50)
            case p
            of "/a": resp(200, 1000)
            of "/b": resp(200, 9000)
            of "/c": resp(403, 50)
            of "/d": resp(403, 9000)
            else: resp(302, 1000, "/x"))
        check r.summary.baseline == bkUnstable
        check findingPaths(r) == @["/b", "/d", "/e"]
        check r.summary.suppressed == 2

    test "a catch-all host reports no findings":
        let paths = @["/a", "/b", "/c", "/d"]
        let r = runBaseline(paths, proc (p: string, n: int): ProbeResult = resp(200, 4096))
        check r.findings.len == 0
        check r.summary.suppressed == paths.len

# Scheduler

proc mkTargets(n: int, scheme = "http"): seq[DirTarget] =
    for i in 0 ..< n:
        result.add(DirTarget(hostname: "h" & $i & ".test", scheme: scheme))

proc mkPaths(n: int): seq[string] =
    for i in 0 ..< n:
        result.add("/p" & $i)

suite "scheduler":
    test "global cap is never exceeded and is reached":
        var cur, peak = 0
        let req = proc (t: DirTarget, p: string): Future[ProbeResult] {.async.} =
            inc cur
            peak = max(peak, cur)
            await sleepAsync(15)
            dec cur
            return resp(200, 10)
        discard waitFor busDirectories(mkTargets(6), mkPaths(8), parseStatusFilter("200"), 0, 3, req)
        check peak == 3

    test "per-host cap is five, baseline probes included":
        var cur, peak = 0
        let req = proc (t: DirTarget, p: string): Future[ProbeResult] {.async.} =
            inc cur
            peak = max(peak, cur)
            await sleepAsync(15)
            dec cur
            return resp(200, 10)
        discard waitFor busDirectories(@[target], mkPaths(30), parseStatusFilter("200"), 0, 20, req)
        check peak == 5
        # two schemes of one host share the cap
        cur = 0; peak = 0
        discard waitFor busDirectories(@[DirTarget(hostname: "t.test", scheme: "http"),
            DirTarget(hostname: "t.test", scheme: "https")], mkPaths(30), parseStatusFilter("200"), 0, 20, req)
        check peak == 5

    test "baseline probes do not bypass the global cap":
        var cur, peak = 0
        let req = proc (t: DirTarget, p: string): Future[ProbeResult] {.async.} =
            inc cur
            peak = max(peak, cur)
            await sleepAsync(15)
            dec cur
            return resp(404, 10)
        # every host starts with two probes: 10 hosts would start 20 at once if probes were free
        discard waitFor busDirectories(mkTargets(10), mkPaths(1), parseStatusFilter("200"), 0, 4, req)
        check peak == 4

    test "rate limit spaces requests, baseline probes counted":
        var starts: seq[float]
        let req = proc (t: DirTarget, p: string): Future[ProbeResult] {.async.} =
            starts.add(epochTime())
            return resp(404, 10)
        let t0 = epochTime()
        # 2 targets: 2 * (2 probes + 6 paths) = 16 requests at 20/s
        discard waitFor busDirectories(mkTargets(2), mkPaths(6), parseStatusFilter("200"), 20, 20, req)
        check starts.len == 16
        check epochTime() - t0 >= 15 * 0.05 * 0.9
        starts.sort()
        for i in 1 ..< starts.len:
            check starts[i] - starts[i - 1] >= 0.05 * 0.5

    test "one request per target and path":
        var seen = initCountTable[string]()
        let req = proc (t: DirTarget, p: string): Future[ProbeResult] {.async.} =
            seen.inc(t.scheme & "://" & t.hostname & p)
            return resp(404, 10)
        let paths = mkPaths(7) & mkPaths(3)
        let ts = mkTargets(3) & mkTargets(3, "https")
        discard waitFor busDirectories(ts, paths, parseStatusFilter("200"), 0, 8, req)
        for t in ts:
            for p in mkPaths(7):
                check seen[t.scheme & "://" & t.hostname & p] == 1
        check seen.len == ts.len * (7 + 2)

    test "failures stay isolated":
        let req = proc (t: DirTarget, p: string): Future[ProbeResult] {.async.} =
            case t.hostname
            of "h0.test": raise newException(IOError, "boom")
            of "h1.test": return ProbeResult()
            else: return resp(if p == "/hit": 200 else: 404, 10)
        let res = waitFor busDirectories(mkTargets(3), @["/hit", "/miss"], parseStatusFilter("200"), 0, 4, req)
        check res.len == 3
        check res[0].summary.unreachable and res[1].summary.unreachable
        check res[2].findings.len == 1 and res[2].findings[0].path == "/hit"

    test "a slow host holding its five slots does not block other hosts":
        let slowHost = "h0.test"
        let slowPaths = mkPaths(20)
        let fastPaths = slowPaths
        var gate = newFuture[void]("gate")
        var fastDone, slowInflight, slowPeak = 0
        let req = proc (t: DirTarget, p: string): Future[ProbeResult] {.async.} =
            if t.hostname == slowHost:
                if p in slowPaths:
                    inc slowInflight
                    slowPeak = max(slowPeak, slowInflight)
                    await gate
                    dec slowInflight
                return resp(404, 10)
            inc fastDone
            return resp(404, 10)
        proc scenario(): Future[seq[DirResult]] {.async.} =
            let run = busDirectories(@[DirTarget(hostname: slowHost, scheme: "http"),
                DirTarget(hostname: "h1.test", scheme: "http")], slowPaths, parseStatusFilter("200"), 0, 20, req)
            let deadline = epochTime() + 5
            while fastDone < 2 + fastPaths.len and epochTime() < deadline:
                await sleepAsync(5)
            check fastDone == 2 + fastPaths.len
            check slowInflight == 5
            check not run.finished
            gate.complete()
            return await run
        let res = waitFor scenario()
        check res.len == 2
        check slowPeak == 5
