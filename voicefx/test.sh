#!/bin/zsh
# Run the DSP test suite. With only the Command Line Tools installed (no Xcode),
# swift-testing lives outside the default search paths: point the compiler at it.
cd "$(dirname "$0")"
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
if [ -d "$F/Testing.framework" ]; then
  swift test -Xswiftc -F"$F" -Xlinker -F"$F" -Xlinker -rpath -Xlinker "$F" "$@"
else
  swift test "$@"
fi
