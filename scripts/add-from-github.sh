#!/usr/bin/env bash

set -o errexit
set -o pipefail

SCRIPT_DIR=$(dirname "$(which "$0")")

function usage {
  echo "Usage $(basename "$0") [-f OVERWRITE_VERSION] REPO_URL COMMIT-SHA [SUBDIRS...]"
  echo
  echo "        -f OVERWRITE_VERSION      (DANGEROUS) uses OVERWRITE_VERSION as the package version instead of the one from the tarball"
  echo "        REPO_URL                  the repository's Github URL"
  echo "        COMMIT_SHA                the commit SHA for the package source"
  echo "        SUBDIRS                   the list of relevant sub-directories"
  exit
}

optstring=":hr:v:"

OVERWRITE_VERSION=

while getopts ${optstring} arg; do
  case ${arg} in
    h)
      usage
      ;;
    f)
      OVERWRITE_VERSION="${OPTARG}"
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

shift $((OPTIND - 1))

REPO_URL="$1" # e.g. https://github.com/input-output-hk/optparse-applicative
REPO_REV="$2"  # e.g. 7497a29cb998721a9068d5725d49461f2bba0e7a

if ! shift 2; then
  usage
fi

SUBDIRS=("$@")

if [[ ${#SUBDIRS[@]} -gt 1 && (-n $OVERWRITE_VERSION) ]]; then
  echo "You can use -f only with a single package"
  exit 1
fi

if [[ ! "$REPO_URL" =~ "https://github.com/" ]]; then
  echo "Provided url is not a github url: $REPO_URL"
  exit 1
fi

TIMESTAMP=$($SCRIPT_DIR/current-timestamp.sh)

render_meta() {
  local TIMESTAMP=$1
  local REPO_URL=$2
  local REPO_REV=$3
  local SUBDIR=$4
  local FORCE_VERSION=$5

  local REPO=${REPO_URL#https://github.com/}

  echo "timestamp = $TIMESTAMP"
  echo "github = { repo = \"$REPO\", rev = \"$REPO_REV\" }"
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
  local REPO_URL=$1
  local REPO_REV=$2
  local SUBDIR=$3
  local WORKDIR=$4

  local CABAL_FILE
  CABAL_FILE=$(echo "$WORKDIR"/"$SUBDIR"/*.cabal)

  local PKG_NAME
  PKG_NAME=$(basename "$CABAL_FILE" .cabal)

  local PKG_VERSION
  PKG_VERSION=$(awk -v IGNORECASE=1 '/^version/ { print $2 }' "$CABAL_FILE")

  if [[ -n $OVERWRITE_VERSION ]]; then
    PKG_VERSION="$OVERWRITE_VERSION"
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
  render_meta "$TIMESTAMP" "$REPO_URL" "$REPO_REV" "$SUBDIR" "$OVERWRITE_VERSION" > "$METAFILE"
  log "Written $METAFILE"

  git add "$METAFILE"
  git commit -m"Added $PKG_ID" -m "From $REPO_URL at $REPO_REV"
}

WORKDIR=$($SCRIPT_DIR/fetch-github-cabal-files.sh $REPO_URL $REPO_REV)

if [[ ${#SUBDIRS[@]} -eq 0 ]]; then
  do_package "$REPO_URL" "$REPO_REV" "" "$WORKDIR"
else
  for subdir in "${SUBDIRS[@]}"; do
    do_package "$REPO_URL" "$REPO_REV" "$subdir" "$WORKDIR"
  done
fi

log "Removing work directory $WORKDIR"
rm -rf "$WORKDIR"
