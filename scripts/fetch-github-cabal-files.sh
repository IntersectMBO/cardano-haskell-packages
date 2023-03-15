#!/usr/bin/env bash

# Fetches a github source tarball and extracts the cabal files.
# Emits the directory with the files to stdout.

set -o errexit
set -o pipefail

SCRIPT_DIR=$(dirname "$(which "$0")")
# Use gnu-tar and gnu-date regardless of whether the OS is Linux
# or BSD-based.  The correct command will be assigned to TAR and DATE
# variables.
source "$SCRIPT_DIR/use-gnu-tar.sh"

log() {
  printf '%s\n' "$*" >&2
}

warning() {
  log "WARNING: $*"
}

REPO_URL=$1
REPO_REV=$2
TAR_URL="$REPO_URL/tarball/$REPO_REV"

if [[ ! "$REPO_URL" =~ "https://github.com/" ]]; then
  echo "Provided url is not a github url: $REPO_URL"
  exit 1
fi

WORKDIR=$(mktemp -d)
pushd "$WORKDIR" > /dev/null

log "Fetching $REPO_URL at revision $REPO_REV to $WORKDIR"

if ! curl --fail --silent --location --remote-name "$TAR_URL"; then
  warning "Failed to download $TAR_URL"
  exit 1
fi

"$TAR" xzf ./* --strip-component=1 --wildcards '**/*.cabal'
popd > /dev/null
echo $WORKDIR
