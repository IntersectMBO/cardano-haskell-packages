#!/usr/bin/env bash

set -euo pipefail

if [[ $1 == --no-commit ]]
then
  NO_COMMIT=1
  shift
fi

PACKAGES=("$@")

if [[ ${#PACKAGES[@]} -eq 0 ]]
then
  echo "Usage: $(basename "$0") PACKAGE ..." >&2
  exit 1
fi

DIR=${0%/*}

for PACKAGE in "${PACKAGES[@]}"
do
  CABAL_FILE=$DIR/$PACKAGE/$PACKAGE.cabal

  if [[ -f "$CABAL_FILE" ]]
  then
    echo "Error: A placeholder already exists for $PACKAGE" >&2
    continue
  fi

  mkdir -p "${CABAL_FILE%/*}"
  sed "s/<package_name>/$PACKAGE/g" "$DIR/package_name.cabal" >"$CABAL_FILE"
  git add "$CABAL_FILE"
done

PLURAL=; [[ ${#PACKAGES[@]} -eq 1 ]] || PLURAL=s

if [[ -z "$NO_COMMIT" ]]
then
  git commit -m "$(printf "Add Hackage candidate placeholder%s for %s" "$PLURAL" "${PACKAGES[*]}")"
  git log -1 --name-status
fi
