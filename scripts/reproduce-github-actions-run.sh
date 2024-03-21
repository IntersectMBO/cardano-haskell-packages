#!/usr/bin/env bash

set -o errexit
set -o pipefail

usage() {
	echo "Usage: $0 [GHA RUN ID] [(DERIVATION=allPackages)]"
}

REPO="input-output-hk/cardano-haskell-packages"

ghaRunId="$1"
derivation="${2:-allPackages}"

if ! shift; then
	usage
	exit 0
fi

ARTIFACT_TEMP_DIR="$(mktemp -d)"
trap '{ echo "Cleaning up $ARTIFACT_TEMP_DIR"; rm -rf -- "$ARTIFACT_TEMP_DIR"; }' EXIT

echo "Downloading artifacts for run $ghaRunId in $ARTIFACT_TEMP_DIR"
gh run download --repo "$REPO" "$ghaRunId" --dir "$ARTIFACT_TEMP_DIR"

echo "Unpacking built-repo in $ARTIFACT_TEMP_DIR/_repo"
mkdir "$ARTIFACT_TEMP_DIR/_repo"
tar xf "$ARTIFACT_TEMP_DIR/built-repo/_repo.tar" -C "$ARTIFACT_TEMP_DIR/_repo"

echo -n "Obtaining commit hash ..."
headSha=$(gh run view --repo "$REPO" "$ghaRunId" --json headSha --jq .headSha)
echo " $headSha"

nix build \
	"github:$REPO/${headSha}#${derivation}" \
	--override-input CHaP "path:$ARTIFACT_TEMP_DIR/_repo" \
	--accept-flake-config true \
	--print-build-logs --show-trace
