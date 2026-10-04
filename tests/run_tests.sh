#!/usr/bin/env sh
# Runs the NeoChess test suite with a headless Godot (Linux and macOS).
#
#   ./tests/run_tests.sh            everything
#   ./tests/run_tests.sh uci        only test files whose name contains "uci"
#
# Godot is taken from $GODOT, then "godot" on PATH.

root=$(cd "$(dirname "$0")/.." && pwd)
filter=${1:-}
godot=${GODOT:-godot}

if ! command -v "$godot" >/dev/null 2>&1; then
    echo "Godot was not found. Set GODOT to the Godot 4.7 binary." >&2
    exit 2
fi

# Make sure the global classes (ChessGame, UciEngine, ...) are registered.
"$godot" --headless --path "$root" --import >/dev/null 2>&1

failed=""
count=0
for test in "$root"/tests/test_*.gd; do
    name=$(basename "$test")
    [ "$name" = "test_base.gd" ] && continue
    case "$name" in *"$filter"*) ;; *) continue ;; esac
    count=$((count + 1))
    echo "== $name"
    if ! "$godot" --headless --path "$root" -s "res://tests/$name" -- --no-engine; then
        failed="$failed $name"
    fi
done

echo
if [ -n "$failed" ]; then
    echo "FAILED:$failed"
    exit 1
fi
echo "All $count test files passed."
