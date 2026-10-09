#!/bin/sh
# Run from any directory. Example: GODOT_BIN=godot4 sh scripts/smoke-test.sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
godot_bin=${GODOT_BIN:-godot}
log_dir=$(mktemp -d "${TMPDIR:-/tmp}/briar-smoke.XXXXXX")
trap 'rm -rf "$log_dir"' EXIT HUP INT TERM
# Isolate test saves and caches from a real player's journey.
export XDG_DATA_HOME="$log_dir/data" XDG_CONFIG_HOME="$log_dir/config" XDG_CACHE_HOME="$log_dir/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
run_check() {
    name=$1; shift
    if "$godot_bin" "$@" >"$log_dir/$name.log" 2>&1; then
        cat "$log_dir/$name.log"
    else
        cat "$log_dir/$name.log" >&2; return 1
    fi
    if grep -E '(^|[[:space:]])(SCRIPT ERROR|ERROR):' "$log_dir/$name.log"; then
        printf '%s\n' "$name reported an error." >&2; return 1
    fi
}
run_check import --headless --path "$project_dir" --import
run_check rules --headless --path "$project_dir" --script tests/test_rules.gd
run_check ui --headless --path "$project_dir" --script tests/test_ui.gd
if [ "${FULL_TESTS:-0}" = "1" ]; then
    run_check fuzz --headless --path "$project_dir" --script tests/fuzz_replay.gd
    run_check drop_transactions --headless --path "$project_dir" --script tests/fuzz_drop_transactions.gd
fi
run_check startup --headless --path "$project_dir" --quit-after 5
if ! grep -Fq 'Briar & Bone ready.' "$log_dir/startup.log"; then
    printf '%s\n' 'The game did not reach its startup callback.' >&2; exit 1
fi
printf '%s\n' 'PASS: project import, deterministic rules, full adventure, and startup.'
