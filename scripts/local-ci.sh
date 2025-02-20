#!/usr/bin/env bash

set -euo pipefail

# Run the equivalent of GH CI locally, in an idempotent, non-mutating way
#
# This can be helpful when investigating build failures because it gives you
# local access to the nix build logs
#
# The nix builds use quite a bit of RAM and nix store space

build-repo()
{
  local REF SHA

  REF=$1
  SHA=$(git rev-parse "$REF")

  if ! [[ -e "_$REF/SHA" ]] || [[ "$(<_"$REF/SHA")" != "$SHA" ]]
  then
    echo "Building repo for $REF" >&2
    rm -rf "_$REF"
    mkdir -p "_$REF"
    git archive "$REF" _sources | tar -x -C "_$REF"
    nix develop --command \
      foliage build -j 0 -v error \
        --write-metadata \
        --input-directory "_$REF/_sources" \
        --output-directory "_$REF/_repo"
    echo "$SHA" >"_$REF/SHA"
  fi
}

build-repo main
build-repo HEAD

rm -rf _repo
cp -a _HEAD/_repo _repo

echo "Building allSmokeTestPackages" >&2
nix build .#allSmokeTestPackages --override-input CHaP path:_repo --show-trace --no-link

scripts/compare-package-metadata.sh _{main,HEAD}/_repo/foliage/packages.json >_repo/foliage/packages.json

echo "Building allPackages" >&2
nix build .#allPackages --override-input CHaP path:_repo --show-trace --no-link
