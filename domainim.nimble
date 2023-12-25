# Package

version       = "0.1.0"
author        = "pptx704"
description   = "A domain reconnaissance tool for bounty hunters"
license       = "MIT"
srcDir        = "src"
bin           = @["domainim"]

# Dependencies
requires "nim >= 2.0.0", "ndns", "regex"