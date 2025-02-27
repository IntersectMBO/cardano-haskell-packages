#!/usr/bin/env bash

set -euo pipefail

# Usage: check-plan [PLAN.JSON]
#
# Check whether a cabal build plan is using the latest packages from CHaP
#
# The CHaP index is fetched using `curl`; the `cardano-haskell-packages` git repo isn't used

PLAN=${1-dist-newstyle/cache/plan.json}

PLAN_VERSIONS=$(mktemp)
CHAP_VERSIONS=$(mktemp)

trap 'rm -f "$PLAN_VERSIONS" "$CHAP_VERSIONS"' EXIT

if tar --version | grep -q 'GNU tar'
then
  tar () { command tar --wildcards "$@"; }
fi

with-header()
{
  if read -r LINE
  then
    echo "$1"
    echo "$LINE"
    cat
  fi
}

jq -r '
  ."install-plan"[]
  | select(."pkg-src".repo.uri // "" | match("^https://chap.intersectmbo.org"; "i"))
  | "\(."pkg-name")/\(."pkg-version")"
' "$PLAN" |
  LANG=C sort -t/ -k1,1 -u -o "$PLAN_VERSIONS"

curl -sSL https://chap.intersectmbo.org/01-index.tar.gz |
  tar -tz \*.cabal |
  cut -d/ -f1-2 |
  LANG=C sort -t/ -k1,1 -k2,2Vr |
  LANG=C sort -t/ -k1,1 -u -o "$CHAP_VERSIONS"

LANG=C join -t/ -j1 "$PLAN_VERSIONS" "$CHAP_VERSIONS" |
  awk -F/ '$2 != $3 {print}' |
  with-header "Package/Plan/CHaP" |
  column -t -s/
