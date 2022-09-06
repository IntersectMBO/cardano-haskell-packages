#!/usr/bin/env bash

set -o errexit
set -o pipefail

REPO_URL="$1" # e.g. input-output-hk/optparse-applicative
REV="$2"  # e.g. 7497a29cb998721a9068d5725d49461f2bba0e7a

if ! shift 2; then
  echo "Usage: $0 REPO_URL REV [SUBDIR...]"
  exit 1
fi

SUBDIRS="$*"

render_meta() {
  local TIMESTAMP=$1
  local URL=$2
  local SUBDIR=$3

  echo "timestamp = $TIMESTAMP"
  echo "url = '$URL'"
  if [[ -n $SUBDIR ]]; then
    echo "subdir = '$SUBDIR'"
  fi
}

log() {
  printf '%s\n' "$*" >&2
}

warning() {
  log "WARNING: $*"
}

do_package() {
  local URL=$1
  local SUBDIR=$2
  local WORKDIR=$3

  local CABAL_FILE
  CABAL_FILE=$(echo "$WORKDIR"/"$SUBDIR"/*.cabal)

  local PKG_NAME
  PKG_NAME=$(basename "$CABAL_FILE" .cabal)

  local PKG_VERSION
  PKG_VERSION=$(awk -v IGNORECASE=1 -e '/^version/ { print $2 }' "$CABAL_FILE")

  local PKG_ID="$PKG_NAME-$PKG_VERSION"

  if [[ -z $PKG_VERSION ]]; then
    warning "cannot extract version from $CABAL_FILE, skipping ..."
    return
  fi

  local METAFILE="_sources/$PKG_NAME/$PKG_VERSION/meta.toml"
  if [[ -f $METAFILE ]]; then
    warning "$METAFILE already exists! you can only publish new versions of a package"
    if [[ -z $SUBDIR ]]; then
      warning "skipping $PKG_ID from $URL"
    else
      warning "skipping $PKG_ID from $URL subdir $SUBDIR"
    fi
    return
  fi

  mkdir -p "$(dirname "$METAFILE")"
  render_meta "$TIMESTAMP" "$URL" "$SUBDIR" > "$METAFILE"
  log "Written $METAFILE"

  git add "$METAFILE"
  git commit -m"Added $PKG_ID" -m "From $REPO_URL at $REV"
}

TAR_URL="$REPO_URL/tarball/$REV"
TIMESTAMP=$(date --utc +%Y-%m-%dT%H:%M:%SZ)

WORKDIR=$(mktemp -d)
log "Work directory is $WORKDIR"
pushd "$WORKDIR"

log "Fetching $REPO_URL at revision $REV"

if ! curl --fail --silent --location --remote-name "$TAR_URL"; then
  echo "Failed to download $TAR_URL"
  exit 1
fi

tar xzf * --strip-component=1 --wildcards '**/*.cabal'
popd

if [[ -z $SUBDIRS ]]; then
  do_package "$TAR_URL" "" "$WORKDIR"
else
  for subdir in $SUBDIRS; do
    do_package "$TAR_URL" "$subdir" "$WORKDIR"
  done
fi

log "Removing work directory $WORKDIR"
rm -rf "$WORKDIR"
