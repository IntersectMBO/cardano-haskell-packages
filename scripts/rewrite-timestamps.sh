#!/usr/bin/env bash

set -euo pipefail

# Amend the current commit by changing all newly-added timestamps to the given one.
# Designed to be used by rebase-and-update-timestamps.sh.
# Will not work on a fixup commit that modifies timestamps.
#
# Usage: rewrite-timestamps.sh TIMESTAMP

if ! git diff @ --quiet
then
  echo "Working directory must not have any changes" >&2
  exit 1
fi

shopt -s extglob

TIMESTAMP=$1
OLDDIFF=$(git log -1 -p)
NEWDIFF=${OLDDIFF//timestamp = *([-0-9:TZ])/timestamp = $TIMESTAMP}

git apply -R <<<"$OLDDIFF"
git apply    <<<"$NEWDIFF"

git commit -a --amend --no-edit
