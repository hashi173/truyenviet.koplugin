#!/usr/bin/env bash
# Run the full unit test suite with KOReader's bundled LuaJIT.
# Usage: bash spec/run_all.sh [--integration]
#   --integration  also run tests that need KOReader native libs (Archiver).
set -u
cd "$(dirname "$0")/.."

LUAJIT="${LUAJIT:-/usr/lib/koreader/luajit}"
if [ ! -x "$LUAJIT" ]; then
    echo "LuaJIT not found at $LUAJIT (set LUAJIT=...)" >&2
    exit 2
fi

TESTS="parser chapter_downloader storage story_results reader document_builder image_utils epub_builder bundle_exporter dtv compile"
if [ "${1:-}" = "--integration" ]; then
    TESTS="$TESTS epub_archive"
fi

pass=0
fail=0
failed=""
for t in $TESTS; do
    out="$("$LUAJIT" "spec/${t}_test.lua" 2>&1)"
    code=$?
    if [ $code -eq 0 ]; then
        pass=$((pass + 1))
        printf 'PASS  %-20s %s\n' "$t" "$(printf '%s' "$out" | tail -n 1)"
    else
        fail=$((fail + 1))
        failed="$failed $t"
        printf 'FAIL  %-20s (exit %d)\n' "$t" "$code"
        printf '%s\n' "$out" | tail -n 15 | sed 's/^/      /'
    fi
done

echo "----"
echo "passed: $pass, failed: $fail${failed:+ ($failed )}"
[ $fail -eq 0 ]
