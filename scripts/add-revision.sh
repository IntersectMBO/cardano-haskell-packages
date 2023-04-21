#!/usr/bin/env bash
set -o errexit
set -o pipefail

SCRIPT_DIR=$(dirname "$(which "$0")")

function usage {
  echo "Usage $(basename "$0") BUILT_REPO PKG_NAME PKG_VERSION"
  echo "  Adds a new revision with the existing cabal file for that package"
  echo "  version. Requires a built repository. Does not commit."
  exit
}

optstring="h"

while getopts ${optstring} arg; do
  case ${arg} in
    h)
      usage
      exit 0
      ;;
    ?)
      echo "Invalid option: -${OPTARG}."
      exit 2
      ;;
  esac
done

shift $((OPTIND - 1))

BUILT_REPO=$1
PKG_NAME=$2
PKG_VERSION=$3

if ! shift 3; then
  usage
  exit 1
fi

META_DIR="_sources/$PKG_NAME/$PKG_VERSION"
META_FILE="$META_DIR/meta.toml"
REVISIONS_DIR="$META_DIR/revisions"

if [[ ! -f "$META_FILE" ]]; then
  echo "Metadata file $META_FILE does not exist"
  exit 1
fi

CURRENT_CABAL_FILE="$BUILT_REPO/index/$PKG_NAME/$PKG_VERSION/$PKG_NAME.cabal"

if [[ ! -f "$CURRENT_CABAL_FILE" ]]; then
  echo "Current cabal file $CURRENT_CABAL_FILE does not exist"
  exit 1
fi

CURRENT_REVISIONS=$(find "$META_DIR" -type f -name "*.cabal")
if [[ -z $CURRENT_REVISIONS ]]; then 
  NEW_REVISION_NUMBER=1
else
  LATEST_REVISION=$(echo "$CURRENT_REVISIONS" | sort | tail -n1)
  LATEST_REVISION_NUMBER=$(basename "$LATEST_REVISION" | cut -f 1 -d '.')
  NEW_REVISION_NUMBER=$((LATEST_REVISION_NUMBER+1))
fi

NEW_CABAL_FILE="$REVISIONS_DIR/$NEW_REVISION_NUMBER.cabal"
echo "Moving $CURRENT_CABAL_FILE to $NEW_CABAL_FILE"

mkdir -p "$REVISIONS_DIR"
cp "$CURRENT_CABAL_FILE" "$NEW_CABAL_FILE"

TIMESTAMP=$($SCRIPT_DIR/current-timestamp.sh)

render_meta() {
  local TIMESTAMP=$1
  local REVISION_NUMBER=$2

  echo "[[revisions]]"
  echo "number = $REVISION_NUMBER"
  echo "timestamp = $TIMESTAMP"
}

echo "Adding meta section for new revision"
# add a blank line between the sections
echo "" >> "$META_FILE"
render_meta "$TIMESTAMP" "$NEW_REVISION_NUMBER" >> "$META_FILE"
