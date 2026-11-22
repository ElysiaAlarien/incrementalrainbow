#!/usr/bin/env bash
# Starts an exported build of the game headless, and checks that it runs.
# Usage: tools/start_check.sh <exported game executable> [frames]
# Works on Linux, macOS, and Windows (Git Bash). See docs/building.md.
#
# The game runs for some frames in an empty user data folder, then quits. The
# check passes when the game exits with code 0, the log has no engine errors,
# and the game wrote a save when it quit. The game writes the save only when
# the content loaded with no errors, so the save shows that the export has the
# content and the scripts.
set -euo pipefail

game="${1:?Usage: tools/start_check.sh <exported game executable> [frames]}"
frames="${2:-300}"
[[ -f "$game" ]] || { echo "start check: no file at $game" >&2; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
log="$work/log.txt"

# Point user:// at the empty folder, so that the check never reads or writes
# a real save.
export XDG_DATA_HOME="$work/data"  # Linux
export HOME="$work/home"           # macOS
mkdir -p "$XDG_DATA_HOME" "$HOME"
log_arg="$log"
if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
	mkdir -p "$work/appdata"
	APPDATA="$(cygpath -w "$work/appdata")"  # Windows
	export APPDATA
	log_arg="$(cygpath -w "$log")"
fi

# A Windows game does not write to the console, so the check reads the log
# file. macOS has no timeout command, so the loop stops a game that does not
# quit in 120 s.
problems=0
"$game" --headless --quit-after "$frames" --log-file "$log_arg" >"$work/console.txt" 2>&1 &
game_pid=$!
for ((second = 0; second < 120; second++)); do
	kill -0 "$game_pid" 2>/dev/null || break
	sleep 1
done
if kill -0 "$game_pid" 2>/dev/null; then
	kill "$game_pid"
	echo "start check: the game did not quit in 120 s" >&2
	problems=1
fi
status=0
wait "$game_pid" || status=$?
if [[ -f "$log" ]]; then
	cat "$log"
else
	cat "$work/console.txt"
fi

if [[ "$status" -ne 0 ]]; then
	echo "start check: the game exited with code $status" >&2
	problems=1
fi
if [[ ! -f "$log" ]]; then
	echo "start check: the game wrote no log" >&2
	problems=1
elif grep -E -q '(^|[^A-Z_])(SCRIPT )?ERROR' "$log"; then
	echo "start check: the log has errors" >&2
	problems=1
fi
save="$(find "$work" -name save.json -path '*app_userdata*' -print -quit)"
if [[ -z "$save" || ! -s "$save" ]]; then
	echo "start check: the game wrote no save, so it did not load its content" >&2
	problems=1
fi
if [[ "$problems" -ne 0 ]]; then
	exit 1
fi
echo "start check: OK ($game ran $frames frames and saved)"
