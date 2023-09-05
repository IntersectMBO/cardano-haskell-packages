#!/usr/bin/env bash

# When run in a Haskell project, and passed a built CHaP repo, goes through the .cabal files and updates the
# bounds on any CHaP packages to be ^>= the latest major versin. The remaining arguments are packages to
# blacklist and not update, in case e.g. you know that the update will break you, or it's your own package!

SCRIPT_DIR=$(dirname "$(which "$0")")

REPO=$1
shift
BLACKLIST=("$@")

update_package_bounds () {
  local PACKAGE=$1
  local VERSION=$2

  IFS='.' read -r -a components <<< "$VERSION"

  local MAJOR_VERSION="${components[0]}.${components[1]}"

  if grep -q --include \*.cabal --exclude-dir dist-newstyle -r "$PACKAGE" .; then
    echo "Updating version bounds on $PACKAGE to '^>=$MAJOR_VERSION'"
    # This is a complicated regex:
    # - Begin capture group
    # - Start by matching the beginning of the line, and insist that the content before the package name
    #   does not include '-'. This is intended to rule out comment lines, which often mention packages.
    #   It's a bit too strong (won't handle 'foo-bar < 1, baz < 2' because of the dash in 'foo-bar'), but
    #   mostly does the job.
    # - Then match the package name
    # - Optionally match a ':{a, b, c}' sub-component expression
    # - Then match some whitespace (at least one). This should be greedy, so get all the whitespace
    #   up to the next thing. We want to include this so the new bound goes in the same place and
    #   hopefully won't mess up formatting.
    # - End capture group
    # - Match any amount of stuff that isn't a comma
    #
    # Then we replace the match with the capture group plus the new bound.
    find . -name "*.cabal" -exec sed -i "s/^\([^-]*$PACKAGE\(:{.*}\)\?\s\+\)[^,\s]*/\1^>=$MAJOR_VERSION/g" {} \;
  else
    echo "No references to $PACKAGE, not updating it"
  fi
}

"$SCRIPT_DIR"/list-latest-package-versions.sh "$REPO" | while read -r PACKAGE VERSION; do
  if [[ " ${BLACKLIST[*]} " =~ ${PACKAGE} ]]; then
    echo "Skipping package $PACKAGE as it is blacklisted"
  else
    update_package_bounds "$PACKAGE" "$VERSION"
  fi
done
