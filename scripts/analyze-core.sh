#!/usr/bin/env bash
# Safe, staged inspection of a retained Snap Store coredump.
# Default: metadata only. Expensive operations require an explicit flag.
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
PID=40117
MODE=metadata
OUT="$ROOT/artifacts"

usage() {
  cat <<'EOF'
Usage: ./scripts/analyze-core.sh [PID] [--extract | --gdb] [--output-dir DIRECTORY]

Default (no flags): read coredump metadata ONLY. Does NOT extract a core
or launch GDB. This is the recommended first step after a system hang.

--extract   Explicitly export the core with limits; do not run GDB.
--gdb       Explicitly export the core and run a bounded, shallow GDB trace.

Resource-limited modes require a functioning systemd --user session,
cgroup v2 memory controls, timeout, prlimit, nice and ionice.
If these safeguards cannot be applied, the script STOPS. It never
falls back to unrestricted GDB.
EOF
}

while (($#)); do
  case "$1" in
    --extract) MODE=extract ;;
    --gdb) MODE=gdb ;;
    --output-dir)
      shift
      if (($# == 0)); then echo 'Missing --output-dir value' >&2; exit 2; fi
      OUT="$1" ;;
    --help|-h) usage; exit 0 ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then PID="$1"
      else printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2
      fi ;;
  esac
  shift
done

command -v coredumpctl >/dev/null || { echo 'Missing coredumpctl' >&2; exit 1; }
command -v timeout >/dev/null || { echo 'Missing timeout' >&2; exit 1; }
mkdir -p -- "$OUT"
INFO="$OUT/snap-store-${PID}-coredump-info.txt"
CORE="$OUT/snap-store-${PID}.core"
REPORT="$OUT/snap-store-${PID}-gdb.txt"
PARTIAL="$CORE.partial"

echo 'Stage 0: retrieving retained crash metadata (15-second limit).'
if ! timeout --signal=TERM --kill-after=3s 15s     coredumpctl info "$PID" --no-pager >"$INFO"; then
  echo "Metadata query failed/timed out; inspect $INFO" >&2
  exit 1
fi
grep -E '^[[:space:]]*(PID:|Signal:|Timestamp:|Executable:|Storage:|Disk Size:)' "$INFO" || true

if [[ "$MODE" == metadata ]]; then
  printf '\nSTOP: metadata-only mode. No core export or GDB was attempted.\n'
  printf 'Metadata file: %s\n' "$INFO"
  printf 'To export deliberately: ./scripts/analyze-core.sh %s --extract\n' "$PID"
  printf 'To run bounded debugging: ./scripts/analyze-core.sh %s --gdb\n' "$PID"
  exit 0
fi

# Everything below is opt-in. Do not bypass these gates automatically.
if ! grep -Eq 'Storage: .*\(present\)' "$INFO"; then
  echo 'Core is no longer marked present; refusing extraction.' >&2
  exit 1
fi
EXECUTABLE="$(sed -n 's/^[[:space:]]*Executable:[[:space:]]*//p' "$INFO" | head -n 1)"
if [[ -z "$EXECUTABLE" || ! -f "$EXECUTABLE" ]]; then
  printf 'Saved executable missing: %s\n' "$EXECUTABLE" >&2
  exit 1
fi

for cmd in systemd-run prlimit nice ionice df; do
  command -v "$cmd" >/dev/null || { printf 'Required limiter missing: %s\n' "$cmd" >&2; exit 1; }
done
if [[ ! -r /sys/fs/cgroup/cgroup.controllers ]] ||
   ! grep -qw memory /sys/fs/cgroup/cgroup.controllers; then
  echo 'cgroup v2 memory controller not available; refusing potentially unbounded analysis.' >&2
  exit 1
fi

# This scope is separate from the desktop. If systemd-run cannot create
# the limited user scope, fail closed; do not invoke gdb/coredumpctl directly.
bounded_run() {
  local seconds="$1"
  shift
  systemd-run --user --scope --wait --collect --quiet     -p MemoryMax=768M -p MemorySwapMax=0 -p CPUQuota=50%     -p TasksMax=32 --     timeout --signal=TERM --kill-after=5s "${seconds}s"     nice -n 15 ionice -c 3 "$@"
}

FREE_KIB="$(df -Pk "$OUT" | awk 'NR==2 {print $4}')"
if [[ ! "$FREE_KIB" =~ ^[0-9]+$ ]] || (( FREE_KIB < 1048576 )); then
  echo 'Less than 1 GiB free disk space (or unknown free space); refusing export.' >&2
  exit 1
fi

echo 'Stage 1: exporting at most 512 MiB under cgroup limits (90-second limit).'
echo 'Note: a larger core will be rejected rather than exhaust system resources.'
trap 'rm -f -- "$PARTIAL"' EXIT
rm -f -- "$PARTIAL"
if ! bounded_run 90 prlimit --fsize=536870912:536870912 --     coredumpctl dump "$PID" --output="$PARTIAL" >/dev/null; then
  echo 'Export failed or resource/time/file-size limit reached; no GDB started.' >&2
  exit 1
fi
if [[ ! -s "$PARTIAL" ]]; then
  echo 'Extracted core is empty; refusing GDB.' >&2
  exit 1
fi
chmod 600 "$PARTIAL"
mv -f -- "$PARTIAL" "$CORE"
printf 'Core exported privately: %s (%s bytes)\n' "$CORE" "$(stat -c %s "$CORE")"

if [[ "$MODE" == extract ]]; then
  echo 'STOP: --extract mode does not launch GDB.'
  exit 0
fi

command -v gdb >/dev/null || { echo 'GDB is not installed; export retained.' >&2; exit 1; }
echo 'Stage 2: shallow GDB crash-thread inspection (60-second limit).'
echo 'No full-thread/full-variable backtrace, debuginfod or startup scripts.'
if ! bounded_run 60 gdb -nx -nh -batch     -iex 'set auto-load off'     -iex 'set debuginfod enabled off'     -x "$SCRIPT_DIR/gdb-commands.gdb"     "$EXECUTABLE" "$CORE" >"$REPORT" 2>&1; then
  echo "GDB failed/timed out/was resource-limited; partial report: $REPORT" >&2
  echo 'Do not increase limits automatically. Inspect system health first.' >&2
  exit 1
fi
chmod 600 "$REPORT"
printf 'Shallow private GDB report: %s\n' "$REPORT"
echo 'Review and redact it before sharing. Never commit a raw core.'
