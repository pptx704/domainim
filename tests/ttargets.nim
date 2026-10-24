import std/[unittest, strutils]
import ../src/targets

suite "domain validation":
    test "valid names":
        for d in ["example.com", "a-b.example.co.uk", "x1.y2.z3", "xn--bcher-kva.example"]:
            check isValidDomain(d)

    test "invalid names are rejected":
        for d in ["", "localhost", "-a.com", "a-.com", "a..com", ".com", "com.", "a b.com",
                  "a_b.com", "http://a.com", "a.com/path", "a.com:80", "A.com",
                  "a".repeat(64) & ".com"]:
            check not isValidDomain(d)

    test "overlong names are rejected":
        check not isValidDomain("a".repeat(64) & ".com")
        check not isValidDomain(("a.".repeat(130)) & "com")

suite "target parsing":
    test "normalises case and whitespace":
        let t = parseTargets(@["  Example.COM ", "B.test"])
        check t.valid == @["example.com", "b.test"]
        check t.invalid.len == 0

    test "dedupes keeping first-seen order":
        let t = parseTargets(@["b.test", "a.test", "B.TEST", "a.test", "c.test"])
        check t.valid == @["b.test", "a.test", "c.test"]

    test "invalid entries are reported and never accepted":
        let t = parseTargets(@["a.test", "not a domain", "localhost", "b.test"])
        check t.valid == @["a.test", "b.test"]
        check t.invalid == @["not a domain", "localhost"]

    test "only invalid input gives no valid targets":
        check parseTargets(@["nope", "-x.com"]).valid.len == 0
        check parseTargets(@[]).valid.len == 0

suite "target file parsing":
    test "skips blank lines and comments":
        let c = "# targets\na.test\n\n   \n  # indented comment\n b.test \r\nc.test"
        check parseTargetFile(c) == @["a.test", "b.test", "c.test"]

    test "empty and comment-only files give nothing":
        check parseTargetFile("").len == 0
        check parseTargetFile("\n# x\n\n").len == 0

    test "file entries flow through validation":
        let t = parseTargets(parseTargetFile("a.test\nbad entry\nA.test\n"))
        check t.valid == @["a.test"]
        check t.invalid == @["bad entry"]
