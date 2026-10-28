#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/artifacts}"
mkdir -p -- "$OUT"

capture() {
  local filename="$1"; shift
  printf 'Collecting %s\n' "$filename"
  ( "$@" ) > "$OUT/$filename" 2>&1 || printf 'WARNING: %s failed; see output\n' "$filename" >&2
}

capture ubuntu.txt bash -c 'lsb_release -a; echo; uname -a; echo; printf "Session: %s\n" "${XDG_SESSION_TYPE:-unknown}"'
capture snap-store.txt bash -c 'snap list snap-store; echo; snap info snap-store'
capture gpu.txt nvidia-smi
capture cpu-topology.txt bash -c 'lscpu -e=CPU,CORE,SOCKET,ONLINE; echo; cat /sys/devices/system/cpu/cpu2/topology/thread_siblings_list'
capture coredump-40117.txt coredumpctl info 40117 --no-pager
capture related-coredumps.txt coredumpctl list snap-store --no-pager
# Journal retention is independent of saved core retention. This can be empty.
capture original-journal-window.txt journalctl -k --since '2026-10-27 16:03:00' --until '2026-10-27 16:05:00' -o short-iso --no-pager
printf '\nSaved local diagnostics under %s (git-ignored). Review for sensitive data before sharing.\n' "$OUT"
