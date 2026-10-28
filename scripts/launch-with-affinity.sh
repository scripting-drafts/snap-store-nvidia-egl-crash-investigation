#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 1 ]]; then
  printf 'Usage: %s CPU_LIST\nExample (after checking topology): %s 0,1,3-7,9-11\n' "$0" "$0" >&2
  exit 2
fi
if ! command -v taskset >/dev/null 2>&1; then
  printf 'taskset is required (util-linux).\n' >&2
  exit 1
fi
printf 'Starting Snap Store with allowed CPUs: %s\n' "$1"
printf 'IMPORTANT: Verify lscpu topology and close other Snap Store instances first.\n'
exec taskset -c "$1" snap run snap-store
