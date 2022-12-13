#!/usr/bin/env bash

# Use gnu-tar and gnu-date regardless of whether the OS is Linux
# or BSD-based.  The correct command will be assigned to TAR and DATE
# variables.
source "$(dirname "$(which "$0")")/use-gnu-tar.sh"

SCRIPT_DIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
BASE_DIR=$(dirname $SCRIPT_DIR)

versions() {
  cat dist-newstyle/cache/plan.json \
    | jq -r '
      ."install-plan"[]
      | select(."pkg-src".repo.uri == "https://input-output-hk.github.io/cardano-haskell-packages")
      | {"pkg-name": ."pkg-name", "pkg-version": ."pkg-version"}
      | @base64' \
    | sort \
    | uniq
}

for x in $(versions); do
  pkg_json="$(echo "\"$x\""  | jq -r '@base64d')"
  pkg_name="$(echo "$pkg_json" | jq -r '."pkg-name"')"
  pkg_version="$(echo "$pkg_json" | jq -r '."pkg-version"')"
  cat "$BASE_DIR/_sources/$pkg_name/$pkg_version/meta.toml" | yj -tj | jq "{\"root\": (. + {\"package\": {\"name\": \"$pkg_name\", \"version\": \"$pkg_version\"}})}"
done | jq -n '.root = [inputs.root] | .root'
