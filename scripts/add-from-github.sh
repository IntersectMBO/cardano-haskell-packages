#!/usr/bin/env bash

set -o errexit
set -o pipefail

function usage {
  echo "Usage $(basename "$0") [-r REVISION] [-v VERSION] REPO_URL REV [SUBDIRS...]"
  echo
  echo "        -r REVISION     adds .0.0.0.0.REVISION to the package version"
  echo "        -v VERSION      uses VERSION as the package version"
  exit
}

optstring=":hr:v:"

REVISION=
VERSION=

while getopts ${optstring} arg; do
  case ${arg} in
    h)
      usage
      ;;
    r)
      REVISION="${OPTARG}"
      ;;
    v)
      VERSION="${OPTARG}"
      ;;
    :)
      echo "$0: Must supply an argument to -$OPTARG." >&2
      exit 1
      ;;
    ?)
      echo "Invalid option: -${OPTARG}."
      exit 2
      ;;
  esac
done

if [[ -n $VERSION && -n $REVISION ]]; then
  echo "You can either use -r or -v but not both at the same time"
  exit 1
fi

shift $((OPTIND - 1))

REPO_URL="$1" # e.g. https://github.com/input-output-hk/optparse-applicative
REPO_REV="$2"  # e.g. 7497a29cb998721a9068d5725d49461f2bba0e7a

if ! shift 2; then
  usage
fi

SUBDIRS=("$@")

if [[ ${#SUBDIRS[@]} -gt 1 && (-n $VERSION || -n $REVISION) ]]; then
  echo "You can use -r or -v only with a single package"
  exit 1
fi

render_meta() {
  local TIMESTAMP=$1
  local URL=$2
  local SUBDIR=$3
  local FORCE_VERSION=$4

  echo "timestamp = $TIMESTAMP"
  echo "url = '$URL'"
  if [[ -n $SUBDIR ]]; then
    echo "subdir = '$SUBDIR'"
  fi
  if [[ -n $FORCE_VERSION ]]; then
    echo "force-version = true"
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

  if [[ -n $VERSION ]]; then
    PKG_VERSION="$VERSION"
  elif [[ -n $REVISION ]]; then
    PKG_VERSION="${PKG_VERSION}.0.0.0.0.${REVISION}"
  fi

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
  render_meta "$TIMESTAMP" "$URL" "$SUBDIR" "$REVISION$VERSION" > "$METAFILE"
  log "Written $METAFILE"

  git add "$METAFILE"
  git commit -m"Added $PKG_ID" -m "From $REPO_URL at $REPO_REV"
}

TAR_URL="$REPO_URL/tarball/$REPO_REV"
TIMESTAMP=$(date --utc +%Y-%m-%dT%H:%M:%SZ)

WORKDIR=$(mktemp -d)
log "Work directory is $WORKDIR"
pushd "$WORKDIR"

log "Fetching $REPO_URL at revision $REPO_REV"

if ! curl --fail --silent --location --remote-name "$TAR_URL"; then
  echo "Failed to download $TAR_URL"
  exit 1
fi

tar xzf ./* --strip-component=1 --wildcards '**/*.cabal'
popd

if [[ ${#SUBDIRS[@]} -eq 0 ]]; then
  do_package "$TAR_URL" "" "$WORKDIR"
else
  for subdir in "${SUBDIRS[@]}"; do
    do_package "$TAR_URL" "$subdir" "$WORKDIR"
  done
fi

log "Removing work directory $WORKDIR"
rm -rf "$WORKDIR"
