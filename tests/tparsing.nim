import std/unittest
import ../src/modules/scannerutils
import ../src/processors

suite "port parsing":
    test "single ports, ranges and lists are sorted":
        check parsePorts("80") == @[80]
        check parsePorts("22,80,53") == @[22, 53, 80]
        check parsePorts("100-103") == @[100, 101, 102, 103]
        check parsePorts("1,10-12,5") == @[1, 5, 10, 11, 12]

    test "all and none":
        check parsePorts("all").len == 65535
        check parsePorts("all")[0] == 1
        check parsePorts("all")[^1] == 65535
        check parsePorts("none").len == 0

    test "top ports start with the most common":
        check parsePorts("t1") == @[80]
        check parsePorts("t3").len == 3
        check 443 in parsePorts("t3")
        check 23 in parsePorts("t3")

    test "invalid specs raise ValueError":
        for spec in ["abc", "0", "65536", "-5", "80-", "200-100", "t0", "80,,90"]:
            expect ValueError:
                discard parsePorts(spec)

    test "duplicates are removed":
        check parsePorts("80,80") == @[80]
        check parsePorts("78-81,80,79") == @[78, 79, 80, 81]
        check processPortString("53,53,t1,80") == @[53, 80]

suite "processPortString":
    test "empty string means no ports":
        check processPortString("").len == 0
        check processPortString("none").len == 0

    test "delegates to parsePorts":
        check processPortString("53,100-102") == @[53, 100, 101, 102]
        expect ValueError:
            discard processPortString("nonsense")

    test "same format is accepted for UDP specs":
        check processPortString("t10").len == 10
        check processPortString("53,123,161") == @[53, 123, 161]
