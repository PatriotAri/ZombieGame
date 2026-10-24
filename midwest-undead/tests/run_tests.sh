#!/usr/bin/env bash
# Runs the game's tests with no window (tests/README.md).
#
#   tests/run_tests.sh                 every test
#   tests/run_tests.sh --quick         every test but the slow ones (tests/slow.txt)
#   tests/run_tests.sh saves_test ...  just these
#
# GODOT is the Godot 4.6 program (default: "godot"). Each test's output goes
# to TEST_OUT (default: a new folder in /tmp), and a test gets TEST_TIMEOUT
# seconds (default 900). The exit status is 1 if any test failed.
set -u

GODOT="${GODOT:-godot}"
OUT="${TEST_OUT:-$(mktemp -d -t midwest-tests.XXXXXX)}"
# Paths given relative to where you are: made absolute before moving to the project.
case "$GODOT" in */*) GODOT="$(cd "$(dirname "$GODOT")" && pwd)/$(basename "$GODOT")" ;; esac
mkdir -p "$OUT" && OUT="$(cd "$OUT" && pwd)"
cd "$(dirname "$0")/.." || exit 1 # the project folder
TIMEOUT="${TEST_TIMEOUT:-900}"

quick=0
names=()
for arg in "$@"; do
	case "$arg" in
		--quick) quick=1 ;;
		*) names+=("${arg%.gd}") ;;
	esac
done
if [ ${#names[@]} -eq 0 ]; then
	for f in tests/*_test.gd; do
		name=$(basename "$f" .gd)
		if [ $quick -eq 1 ] && grep -qx "$name" tests/slow.txt 2>/dev/null; then
			continue
		fi
		names+=("$name")
	done
fi

# A fresh checkout has no .godot folder: import first (the class list, the
# imported sounds and textures).
echo "Importing the project..."
if ! timeout "$TIMEOUT" "$GODOT" --headless --path . --import > "$OUT/import.log" 2>&1; then
	if grep -q "SCRIPT ERROR\|Parse Error" "$OUT/import.log"; then
		grep "SCRIPT ERROR\|Parse Error" "$OUT/import.log" | head -20
		echo "The project has script errors (see $OUT/import.log)."
		exit 1
	fi
fi

failed=()
for name in "${names[@]}"; do
	if [ ! -f "tests/$name.gd" ]; then
		echo "  ??   $name (no tests/$name.gd)"
		failed+=("$name")
		continue
	fi
	start=$(date +%s)
	timeout "$TIMEOUT" "$GODOT" --headless --path . --fixed-fps 60 -s "res://tests/$name.gd" > "$OUT/$name.log" 2>&1
	status=$?
	took=$(( $(date +%s) - start ))
	result=$(grep -h "^FAILS: " "$OUT/$name.log" | tail -1)
	errors=$(grep -c "SCRIPT ERROR" "$OUT/$name.log")
	if [ $status -eq 124 ]; then
		why="timed out after ${TIMEOUT}s"
	elif [ -z "$result" ]; then
		why="ended without a result"
	elif [ "$result" != "FAILS: 0" ]; then
		why="${result#FAILS: } check(s) failed"
	elif [ "$errors" -gt 0 ]; then
		why="$errors script error(s)"
	else
		why=""
	fi
	if [ -z "$why" ]; then
		printf "  ok   %-24s %4ss\n" "$name" "$took"
	else
		printf "  FAIL %-24s %4ss  %s\n" "$name" "$took" "$why"
		grep -h "^  FAIL\|SCRIPT ERROR" "$OUT/$name.log" | head -5 | sed 's/^/         /'
		failed+=("$name")
	fi
done

echo
echo "${#names[@]} tests, ${#failed[@]} failed. Output: $OUT"
[ ${#failed[@]} -eq 0 ]
