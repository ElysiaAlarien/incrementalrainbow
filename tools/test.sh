#!/usr/bin/env bash
# Import the project headless, then run the GUT test suite.
# Usage: tools/test.sh [extra GUT options, for example -gselect=test_big_number.gd]
# Set GODOT to the Godot 4 binary if it is not on PATH as "godot".
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --import
mkdir -p test-results
"$GODOT" --headless -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json "$@"
