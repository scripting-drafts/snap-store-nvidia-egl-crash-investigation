#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
REPO='scripting-drafts/snap-store-nvidia-egl-crash-investigation'

for tool in gh git; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Missing: $tool" >&2; exit 1; }
done

gh auth status >/dev/null
if gh repo view "$REPO" >/dev/null 2>&1; then
  echo "Repository already exists: https://github.com/$REPO" >&2
  echo 'Review its contents and push manually; refusing to overwrite or reuse it automatically.' >&2
  exit 1
fi

if [[ -d .git ]]; then
  echo 'A Git checkout already exists here; refusing automatic initialization.' >&2
  exit 1
fi

git init -b main
# Stage only known project paths. Raw cores and diagnostics are deliberately omitted.
git add -- .gitignore LICENSE README.md docs scripts
git commit -m 'Document Snap Store NVIDIA EGL SIGSEGV investigation (#2271)'
gh repo create "$REPO" --public --source=. --remote=origin --push
printf 'Repository published: https://github.com/%s\n' "$REPO"
