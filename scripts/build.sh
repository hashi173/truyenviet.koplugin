#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DIST="$ROOT/dist"
ARCHIVE="$DIST/truyenviet.koplugin.zip"

mkdir -p "$DIST"
rm -f "$ARCHIVE"
cd "$ROOT"
if find truyenviet.koplugin -type l -print -quit | grep -q .; then
    printf '%s\n' "Plugin contains an invalid symbolic link." >&2
    exit 1
fi
find truyenviet.koplugin -type f -print | zip -q "$ARCHIVE" -@
printf '%s\n' "$ARCHIVE"
