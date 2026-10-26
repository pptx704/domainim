import std/[asyncdispatch, httpclient, net, strutils, sequtils, sets, tables, deques, random, times, algorithm]

const
    requestTimeoutMs* = 10000 # one deadline for connect, headers and body
    bodyCap* = 65536          # body bytes read per response
    hostCap* = 5              # in-flight requests per host
    userAgent = "Mozilla/5.0 (compatible; domainim)"

randomize()

type
    DirFinding* = object
        scheme*: string
        path*: string
        status*: int
        size*: int
        redirect*: string

    DirTarget* = object
        hostname*: string
        scheme*: string

    BaselineKind* = enum
        bkUnreachable, ## no probe got an answer
        bkNotFound,    ## unknown paths answer 404, nothing is filtered
        bkStable,      ## unknown paths answer one status
        bkUnstable     ## unknown paths answer different statuses

    DirSummary* = object
        baseline*: BaselineKind
        suppressed*: int
        unreachable*: bool

    DirResult* = object
        target*: DirTarget
        findings*: seq[DirFinding]
        summary*: DirSummary

    ProbeResult* = object
        ok*: bool ## false when the request failed or timed out
        status*: int
        size*: int
        location*: string

    RequestProc* = proc (target: DirTarget, path: string): Future[ProbeResult] {.closure.}
    ProgressProc* = proc (done, total: int) {.closure.}

    StatusFilter* = seq[HSlice[int, int]]

    Sample* = object
        status*: int
        size*: int
        location*: string ## with the probe path replaced by a placeholder

    Baseline* = object
        kind*: BaselineKind
        samples*: seq[Sample]

    Decision* = enum
        dkIgnore, ## status is not in the filter
        dkKeep,
        dkDrop

const placeholder = "{path}"

# Pure parts

proc parseWordlist*(text: string): seq[string] =
    ## Raises `ValueError` when no path is left
    var seen: HashSet[string]
    for raw in text.splitLines:
        var line = raw.strip
        if line.len == 0 or line.startsWith("#"):
            continue
        if not line.startsWith("/"):
            line = "/" & line
        if not seen.containsOrIncl(line):
            result.add(line)
    if result.len == 0:
        raise newException(ValueError, "The wordlist has no paths")

proc parseStatusFilter*(spec: string): StatusFilter =
    ## Parses `200,301-303`. Raises `ValueError` for an invalid specification
    proc code(s: string): int =
        result = s.strip.parseInt
        if result notin 100..599:
            raise newException(ValueError, "Invalid status code " & s)
    for chunk in spec.split(","):
        let parts = chunk.split("-")
        case parts.len
        of 1:
            let c = code(parts[0])
            result.add(c..c)
        of 2:
            let (a, b) = (code(parts[0]), code(parts[1]))
            if a > b:
                raise newException(ValueError, "Invalid status range " & chunk)
            result.add(a..b)
        else:
            raise newException(ValueError, "Invalid status range " & chunk)

proc contains*(filter: StatusFilter, status: int): bool =
    for r in filter:
        if status in r:
            return true

proc normalizeLocation*(location, path: string): string =
    ## Replaces the requested path so redirects of different paths can be compared
    if location.len == 0 or path.len == 0:
        return location
    location.replace(path, placeholder)

proc classifyBaseline*(samples: seq[Sample]): Baseline =
    ## `samples` holds the probes that got an answer
    result.samples = samples
    if samples.len == 0:
        result.kind = bkUnreachable
    elif samples.allIt(it.status == 404):
        result.kind = bkNotFound
    elif samples.allIt(it.status == samples[0].status):
        result.kind = bkStable
    else:
        result.kind = bkUnstable

proc tolerance(size: int): int =
    max(16, size div 20)

proc matches(s: Sample, status, size: int, location: string): bool =
    ## Same status, similar size and, for redirects, the same target
    if status != s.status:
        return false
    if abs(size - s.size) > tolerance(max(size, s.size)):
        return false
    status notin 300..399 or location == s.location

proc decide*(b: Baseline, filter: StatusFilter, status, size: int, location: string): Decision =
    ## `location` is normalized like the samples
    if status notin filter:
        return dkIgnore
    case b.kind
    of bkUnreachable, bkNotFound:
        return dkKeep
    of bkStable:
        var
            lo = high(int)
            hi = 0
            sameLocation = false
        for s in b.samples:
            lo = min(lo, s.size)
            hi = max(hi, s.size)
            sameLocation = sameLocation or s.location == location
        let tol = tolerance(hi)
        if status == b.samples[0].status and size in lo - tol .. hi + tol and
                (status notin 300..399 or sameLocation):
            return dkDrop
    of bkUnstable:
        for s in b.samples:
            if matches(s, status, size, location):
                return dkDrop
    dkKeep

# Request layer

var tlsContext: SslContext

proc fetch(client: AsyncHttpClient, url: string): Future[ProbeResult] {.async.} =
    let resp = await client.request(url, HttpGet)
    result.status = resp.code.int
    result.location = resp.headers.getOrDefault("location")
    # The body is counted chunk by chunk and dropped; it is never stored
    while result.size < bodyCap:
        let (hasData, chunk) = await resp.bodyStream.read()
        if not hasData:
            break
        result.size += chunk.len
    result.size = min(result.size, bodyCap)
    result.ok = true

proc httpRequestWithin*(target: DirTarget, path: string, timeoutMs: int): Future[ProbeResult] {.async.} =
    ## GET without redirects. Failures and timeouts give `ok = false`
    if tlsContext.isNil:
        tlsContext = newContext(verifyMode = CVerifyNone)
    let
        host = if target.hostname.isIpAddress and ':' in target.hostname: "[" & target.hostname & "]" else: target.hostname
        url = target.scheme & "://" & host & path
        client = newAsyncHttpClient(userAgent, maxRedirects = 0, sslContext = tlsContext)
    try:
        let fut = fetch(client, url)
        fut.addCallback(proc () =
            if fut.failed:
                discard fut.readError) # an expired or closed request must not leave an unread error
        if await withTimeout(fut, timeoutMs):
            result = fut.read
    except CatchableError:
        result = ProbeResult()
    finally:
        try:
            client.close()
        except CatchableError:
            discard

proc httpRequest*(target: DirTarget, path: string): Future[ProbeResult] =
    httpRequestWithin(target, path, requestTimeoutMs)

# Scheduler

type
    Job = object
        target: int
        path: string
        order: int ## position in the wordlist, -1 for a baseline probe

    HostQueue = object
        jobs: Deque[Job]
        inflight: int

    TargetState = object
        host: int
        probesLeft: int
        samples: seq[Sample]
        probePaths: seq[string]
        baseline: Baseline
        found: seq[(int, DirFinding)]
        suppressed: int

    Scheduler = ref object
        targets: seq[DirTarget]
        paths: seq[string]
        filter: StatusFilter
        request: RequestProc
        progress: ProgressProc
        concurrency: int
        interval: float
        nextSlot: float
        inflight: int
        cursor: int
        done: int
        total: int
        hosts: seq[HostQueue]
        states: seq[TargetState]
        wake: Future[void]

proc randomPath(): string =
    result = "/"
    for _ in 0 ..< 16:
        result.add("0123456789abcdef"[rand(15)])

proc waitSlot(s: Scheduler) {.async.} =
    ## Reserves the next free start time so requests are spread at the rate limit
    if s.interval <= 0:
        return
    let
        now = epochTime()
        slot = max(s.nextSlot, now)
    s.nextSlot = slot + s.interval
    if slot - now >= 0.001:
        await sleepAsync(int((slot - now) * 1000))

proc finishBaseline(s: Scheduler, ti: int) =
    template st: untyped = s.states[ti]
    st.baseline = classifyBaseline(st.samples)
    if st.baseline.kind == bkUnreachable:
        s.total -= s.paths.len
        return
    for i, p in s.paths:
        s.hosts[st.host].jobs.addLast(Job(target: ti, path: p, order: i))

proc complete(s: Scheduler, job: Job, r: ProbeResult) =
    let hi = s.states[job.target].host
    template st: untyped = s.states[job.target]
    dec s.inflight
    dec s.hosts[hi].inflight
    inc s.done
    if job.order < 0:
        if r.ok:
            st.samples.add(Sample(status: r.status, size: r.size,
                location: normalizeLocation(r.location, job.path)))
        dec st.probesLeft
        if st.probesLeft == 0:
            finishBaseline(s, job.target)
    elif r.ok:
        let loc = normalizeLocation(r.location, job.path)
        case decide(st.baseline, s.filter, r.status, r.size, loc)
        of dkKeep:
            st.found.add((job.order, DirFinding(scheme: s.targets[job.target].scheme,
                path: job.path, status: r.status, size: r.size, redirect: r.location)))
        of dkDrop:
            inc st.suppressed
        of dkIgnore:
            discard
    if not s.progress.isNil:
        s.progress(s.done, s.total)
    if not s.wake.finished:
        s.wake.complete()

proc runJob(s: Scheduler, job: Job) {.async.} =
    var r = ProbeResult()
    try:
        await waitSlot(s)
        r = await s.request(s.targets[job.target], job.path)
    except CatchableError:
        r = ProbeResult()
    complete(s, job, r)

proc dispatch(s: Scheduler) =
    ## Starts jobs from any host with a free slot. It never waits for a slot
    ## of one host, so a slow host cannot hold the workers of the others.
    while s.inflight < s.concurrency:
        var picked = -1
        for k in 0 ..< s.hosts.len:
            let h = (s.cursor + k) mod s.hosts.len
            if s.hosts[h].inflight < hostCap and s.hosts[h].jobs.len > 0:
                picked = h
                break
        if picked < 0:
            return
        s.cursor = (picked + 1) mod s.hosts.len
        let job = s.hosts[picked].jobs.popFirst
        inc s.inflight
        inc s.hosts[picked].inflight
        asyncCheck runJob(s, job)

proc busDirectories*(targets: seq[DirTarget], paths: seq[string], filter: StatusFilter,
        rps, concurrency: int, request: RequestProc = httpRequest,
        progress: ProgressProc = nil): Future[seq[DirResult]] {.async.} =
    ## Probes every path on every target. Each target first gets two baseline
    ## probes, which count toward the rate and concurrency limits.
    let s = Scheduler(targets: targets, paths: deduplicate(paths), filter: filter,
        request: request, progress: progress, concurrency: max(1, concurrency),
        interval: if rps > 0: 1.0 / rps.float else: 0.0)
    var hostIndex: Table[string, int]
    for ti, t in targets:
        let key = t.hostname.toLowerAscii
        if key notin hostIndex:
            hostIndex[key] = s.hosts.len
            s.hosts.add(HostQueue())
        var st = TargetState(host: hostIndex[key], probesLeft: 2)
        for _ in 0 ..< 2:
            var p = randomPath()
            while p in st.probePaths:
                p = randomPath()
            st.probePaths.add(p)
            s.hosts[st.host].jobs.addLast(Job(target: ti, path: p, order: -1))
        s.states.add(st)
        s.total += 2 + s.paths.len
    while true:
        s.wake = newFuture[void]("dirbuster.wake")
        dispatch(s)
        if s.inflight == 0:
            break
        await s.wake
    for ti, t in targets:
        var st = s.states[ti]
        st.found.sort(proc (a, b: (int, DirFinding)): int = cmp(a[0], b[0]))
        var res = DirResult(target: t, summary: DirSummary(baseline: st.baseline.kind,
            suppressed: st.suppressed, unreachable: st.baseline.kind == bkUnreachable))
        for (_, f) in st.found:
            res.findings.add(f)
        result.add(res)
