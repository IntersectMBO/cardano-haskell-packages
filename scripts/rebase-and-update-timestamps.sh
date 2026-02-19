#!/usr/bin/env bash

set -euo pipefail

# Rebase the current branch and modify its commits to use a different timestamp
#
# Usage: rebase-and-update-timestamps.sh [BASE [TIMESTAMP]]
#
# BASE        The branch to rebase onto (default: origin/main)
# TIMESTAMP   The timestamp to use (default: now)

# Add this script's directory to PATH if it wasn't already there
case $0 in
  (*/*) PATH=${0%/*}:$PATH;;
esac

BASE=${1:-origin/main}
TIMESTAMP=${2:-$(current-timestamp.sh)}

git rebase "$BASE" --exec "rewrite-timestamps.sh '$TIMESTAMP'"
