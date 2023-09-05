#!/usr/bin/env bash
# Creates a fixup commit for the given revision that updates any
# timestamps introduced in that revision

set -o errexit
set -o pipefail

SCRIPT_DIR=$(dirname "$(which "$0")")

REVISION="$1"

echo "Updating timestamps in commit $(git rev-parse "$REVISION")"

"$SCRIPT_DIR"/update-timestamps-in-revision.sh "$REVISION"

git add _sources

if git diff --quiet --cached --exit-code; then
  echo "No changes were made, nothing to commit"
else
  echo " Committing changes"
  git commit --fixup="$REVISION"
fi
