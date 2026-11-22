#!/usr/bin/env bash
# Exports the game with the presets in export_presets.cfg. See docs/building.md.
# Usage: tools/build.sh [--debug] <preset>...
#   tools/build.sh Linux Windows macOS
#   tools/build.sh --debug Android
# Each build goes to the export_path of its preset, under build/.
# Set GODOT to the Godot 4 editor binary if it is not on PATH as "godot". The
# export templates of the same Godot version must be installed.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"

mode="--export-release"
if [[ "${1:-}" == "--debug" ]]; then
	mode="--export-debug"
	shift
fi
if [[ "$#" -eq 0 ]]; then
	echo "Usage: tools/build.sh [--debug] <preset>..." >&2
	exit 2
fi

# The export_path of the preset named $1.
export_path() {
	awk -v want="$1" '
		/^\[preset\.[0-9]+\]$/ { in_preset = 1; name = ""; next }
		/^\[/ { in_preset = 0 }
		in_preset && /^name=/ { name = substr($0, 7, length($0) - 7) }
		in_preset && /^export_path=/ && name == want { print substr($0, 14, length($0) - 14); exit }
	' export_presets.cfg
}

"$GODOT" --headless --import

for preset in "$@"; do
	path="$(export_path "$preset")"
	if [[ -z "$path" ]]; then
		echo "build: export_presets.cfg has no preset named \"$preset\" with an export_path" >&2
		exit 1
	fi
	mkdir -p "$(dirname "$path")"
	rm -rf "$path"
	log="build/$preset.log"
	echo "build: $preset ($mode) to $path"
	status=0
	"$GODOT" --headless "$mode" "$preset" "$PWD/$path" 2>&1 | tee "$log" || status=$?
	# An export can print errors and still exit 0, so check the log and the file.
	if [[ "$status" -ne 0 ]]; then
		echo "build: $preset failed with code $status" >&2
		exit 1
	fi
	if grep -E -q '(^|[^A-Z_])(SCRIPT )?ERROR' "$log"; then
		echo "build: the $preset export log has errors (see $log)" >&2
		exit 1
	fi
	if [[ ! -s "$path" && ! -d "$path" ]]; then
		echo "build: $preset made no file at $path" >&2
		exit 1
	fi
	echo "build: $preset OK: $(du -sh "$path" | cut -f1) at $path"
done
