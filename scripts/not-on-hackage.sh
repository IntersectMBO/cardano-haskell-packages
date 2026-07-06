#!/usr/bin/env bash

set -euo pipefail

# Output any package names given on the command line that do not exist on Hackage,
# either as published packages or as unpublished candidates

# Unfortunately, the /package/$PACKAGE/candidates/ API endpoint doesn't exist if $PACKAGE
# has never been published, so we have to download the list of all candidates and
# check whether $PACKAGE appears in it

CANDIDATES=$(mktemp)
trap 'rm -f "$CANDIDATES"' EXIT

curl -fsSH 'Accept: application/json' "https://hackage.haskell.org/packages/candidates/" |
  jq -r 'map(.name) | unique | .[]' >"$CANDIDATES"

for PACKAGE
do
  # Skip if a candidate
  ! grep -qFxe "$PACKAGE" "$CANDIDATES" || continue

  # Skip if published
  ! curl -fsIH 'Accept: application/json' "https://hackage.haskell.org/package/$PACKAGE" -o /dev/null || continue

  echo "$PACKAGE"
done
