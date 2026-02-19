#!/usr/bin/env bash

set -euo pipefail

# Update a PR branch that's out of date wrt the tip of main.
#
# Usage: update-branch.sh BRANCH

if ! git diff @ --quiet
then
  echo "Working directory must not have any changes" >&2
  exit 1
fi

BRANCH=$1

git remote update -p
git checkout "$BRANCH"
git reset --keep '@{u}'

scripts/rebase-and-update-timestamps.sh

git push --force-with-lease
