#!/usr/bin/env bash
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
PID="${1:-40117}"
OUT="${2:-$ROOT/artifacts}"

if [[ ! "$PID" =~ ^[0-9]+$ ]]; then
  printf 'Expected numeric PID, received %q\n' "$PID" >&2
  exit 2
fi
for command in coredumpctl gdb; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Missing command: %s\n' "$command" >&2
    exit 1
  fi
done

mkdir -p -- "$OUT"
CORE="$OUT/snap-store-${PID}.core"
REPORT="$OUT/snap-store-${PID}-gdb.txt"
INFO="$OUT/snap-store-${PID}-coredump-info.txt"

coredumpctl info "$PID" --no-pager > "$INFO"
if ! grep -Eq 'Storage: .*\(present\)' "$INFO"; then
  printf 'The requested core is not marked present; inspect %s\n' "$INFO" >&2
  exit 1
fi

EXECUTABLE="$(sed -n 's/^[[:space:]]*Executable:[[:space:]]*//p' "$INFO" | head -n 1)"
if [[ -z "$EXECUTABLE" || ! -f "$EXECUTABLE" ]]; then
  printf 'Executable from core metadata was not found: %s\n' "$EXECUTABLE" >&2
  exit 1
fi

printf 'Exporting PID %s to %s\n' "$PID" "$CORE"
coredumpctl dump "$PID" --output="$CORE" >/dev/null
chmod 600 "$CORE"
printf 'Analyzing executable %s\n' "$EXECUTABLE"
if ! gdb -batch -x "$SCRIPT_DIR/gdb-commands.gdb" "$EXECUTABLE" "$CORE" > "$REPORT" 2>&1; then
  printf 'GDB exited non-zero; see diagnostic output at %s\n' "$REPORT" >&2
  exit 1
fi
chmod 600 "$REPORT"
printf '\nReport: %s\nCore: %s\n' "$REPORT" "$CORE"
printf 'Both files are private local artifacts. Review/redact the report; never commit the raw core.\n'
