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
  echo "$*" >&2
}

# NOTE: This function prints to stdout the package id (which is not known beforehand).
do_package() {
  local URL=$1
  local SUBDIR=$2
  local WORKDIR=$3

  local cabal_file
  cabal_file=$(echo "$WORKDIR"/"$SUBDIR"/*.cabal)

  local pkg_name
  pkg_name=$(basename "$cabal_file" .cabal)

  local pkg_version
  pkg_version=$(awk -v IGNORECASE=1 -e '/^version/ { print $2 }' "$cabal_file")

  local pkg_id="$pkg_name-$pkg_version"

  if [[ -z $pkg_version ]]; then
    log "cannot extract version from $cabal_file, skipping ..."
    return
  fi

  local metafile="_sources/$pkg_name/$pkg_version/meta.toml"
  if [[ -f $metafile ]]; then
    log "$metafile already exists! you can only publish new versions of a package"
    if [[ -z $SUBDIR ]]; then
      log "skipping $pkg_id from $URL"
    else
      log "skipping $pkg_id from $URL subdir $SUBDIR"
    fi
    return
  fi

  mkdir -p "$(dirname "$metafile")"
  render_meta "$TIMESTAMP" "$URL" "$SUBDIR" > "$metafile"
  log "Written $metafile"
  echo "$pkg_id"
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
