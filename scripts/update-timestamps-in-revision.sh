#!/usr/bin/env bash
# Updates any timestamps which were introduced in the given revision

# Don't set pipefail since the pipeline below can fail if there are
# no changes to be made
set -o errexit

SCRIPT_DIR=$(dirname "$(which "$0")")

REVISION="$1"

# 1. Print the diff, including only changed lines (no context) in _sources
# 2. Filter for 'timestamp = <something>'
# 3. Cut out just the timestamp
TIMESTAMPS_IN_DIFF=$(git show "$REVISION" --patch --unified=0 -- _sources | grep -oP "timestamp = (.*)" | cut -f 3 -d ' ')

echo "Found the following timestamps in the diff: $TIMESTAMPS_IN_DIFF"

for OLD_TIMESTAMP in $TIMESTAMPS_IN_DIFF; do
  NEW_TIMESTAMP=$("$SCRIPT_DIR"/current-timestamp.sh)
  echo "Replacing $OLD_TIMESTAMP with $NEW_TIMESTAMP"
  # Blindly replace the old timestamp with a fresh timestamp in every meta.toml. This assumes
  # that the timestamp that we found in the diff was unique, and so this will only hit that
  # file, which is pretty safe.
  find _sources -type f -name "meta.toml" -exec sed -i s/"$OLD_TIMESTAMP"/"$NEW_TIMESTAMP"/g {} +
done
