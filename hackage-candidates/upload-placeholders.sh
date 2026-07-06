#!/usr/bin/env bash

set -euo pipefail

PACKAGES=("$@")

if [[ ${#PACKAGES[@]} -eq 0 ]]
then
  echo "Usage: $(basename "$0") PACKAGE ..." >&2
  exit 1
fi

if [[ -z "${HACKAGE_TOKEN:-}" ]]; then
  echo "Error: The HACKAGE_TOKEN environment variable is not set"
  exit 1
fi

DIR=${0%/*}

for PACKAGE in "${PACKAGES[@]}"
do
  CABAL_FILE=$DIR/$PACKAGE/$PACKAGE.cabal

  if ! [[ -f "$CABAL_FILE" ]]
  then
    echo "Error: A placeholder doesn't exist for $PACKAGE" >&2
    continue
  fi

  VERSION=$(sed -n '/^version: */Is///p' "$CABAL_FILE")

  (
    cd "${CABAL_FILE%/*}"
    trap 'rm -rf dist-newstyle' EXIT
    cabal -z sdist
    cabal upload "dist-newstyle/sdist/$PACKAGE-$VERSION.tar.gz" --token "$HACKAGE_TOKEN"
    curl -X PUT -H "Authorization: X-ApiKey $HACKAGE_TOKEN" \
      "https://hackage.haskell.org/package/$PACKAGE/maintainers/user/IOHK"
  )
done
