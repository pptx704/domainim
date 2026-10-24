# Package

version       = "1.3.0"
author        = "pptx704"
description   = "A domain reconnaissance tool for bounty hunters"
license       = "MIT"
srcDir        = "src"
bin           = @["domainim"]

# Dependencies
requires "nim >= 2.0.0", "ndns >= 0.1.4", "regex >= 0.27.0"

task test, "Run the unit tests":
    for t in ["tparsing", "tresults", "tudpscanner", "tipv6", "ttargets", "tmultidomain"]:
        exec "nim c -r --hints:off --outdir:tests/bin tests/" & t & ".nim"
