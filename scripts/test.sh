#!/bin/bash
# Runs the unit tests. With only Apple's Command Line Tools (no Xcode), Swift Testing
# is not on the default search paths, so add them here.
set -euo pipefail
cd "$(dirname "$0")/.."

flags=()
clt=/Library/Developer/CommandLineTools/Library/Developer
if [[ "$(xcode-select -p)" == /Library/Developer/CommandLineTools ]]; then
    flags=(-Xswiftc -F -Xswiftc "$clt/Frameworks"
           -Xlinker -F -Xlinker "$clt/Frameworks"
           -Xlinker -rpath -Xlinker "$clt/Frameworks"
           -Xlinker -rpath -Xlinker "$clt/usr/lib")
fi
swift test "${flags[@]}" "$@"
