#!/usr/bin/env bash
# Makes a dummy commit for testing.
#   scripts/commit.sh "feat: add login button"            appends to src/changes.txt
#   scripts/commit.sh "fix: tweak" src/other.txt           appends to another file
set -euo pipefail
msg=${1:?usage: scripts/commit.sh "<type>: <message>" [file]}
file=${2:-src/changes.txt}
mkdir -p "$(dirname "$file")"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $msg" >> "$file"
git add "$file"
git commit -q -m "$msg"
git log -1 --oneline
