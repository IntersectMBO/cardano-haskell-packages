#!/usr/bin/env bash

set -o errexit
set -o pipefail

backup_if_exists() {
  local fn="$1"
  available() {
    if [[ -e "$fn~$1" ]]; then
      available $(($1+1))
    else
      echo "$fn~$1"
    fi
  }
  if [[ -e $fn ]]; then
    mv "$fn" "$(available)"
  fi
}

render_meta() {
  local TIMESTAMP=$1
  local URL=$2
  local SUBDIR=$3

  echo "timestamp = '$TIMESTAMP'"
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

# NOTE: This function prints to stdout the package id (which is not known beforehand).
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
  echo "$PKG_ID"
}

REPO_URL="$1" # e.g. input-output-hk/optparse-applicative
REV="$2"  # e.g. 7497a29cb998721a9068d5725d49461f2bba0e7a

if ! shift 2; then
  echo "Usage: $0 REPO_URL REV [SUBDIR...]"
  exit 1
fi

SUBDIRS="$*"

TAR_URL="$REPO_URL/tarball/$REV"
TIMESTAMP=$(date --utc +%Y-%m-%dT%H:%M:%SZ)

WORKDIR=$(mktemp -d)
log "Work directory is $WORKDIR"

log "Fetching $REPO_URL at revision $REV"
curl --silent --location "$TAR_URL" | tar xz -C "$WORKDIR" --strip-component=1 --wildcards '**/*.cabal'

backup_if_exists COMMIT_MSG.txt
echo "Added $REPO_URL@$REV" > COMMIT_MSG.txt
echo "" >> COMMIT_MSG.txt

if [[ -z $SUBDIRS ]]; then
  pkg_id=$(do_package "$TAR_URL" "" "$WORKDIR")
  echo " - $pkg_id" >> COMMIT_MSG.txt
else
  for subdir in $SUBDIRS; do
    pkg_id=$(do_package "$TAR_URL" "$subdir" "$WORKDIR")
    echo " - $pkg_id" >> COMMIT_MSG.txt
  done
fi

log "Removing work directory $WORKDIR"
rm -rf "$WORKDIR"

log "Now run something like"
log "  git add _sources"
log "  git commit -eF COMMIT_MSG.txt --date='$TIMESTAMP'"
log "to commit the changes"
