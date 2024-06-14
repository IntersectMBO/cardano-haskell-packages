#!/usr/bin/env bash
TEMP_DIR="$(mktemp -d)"
log() {
  printf '%s\n' "$*" >&2
}
log "Created result temp dir: $TEMP_DIR"
log "Gathering package info to: $TEMP_DIR/package-revs.txt"
scripts/list-latest-package-revs.sh > "$TEMP_DIR/package-revs.txt"
awk '{print "https://github.com/" $1 " " $3}' < "$TEMP_DIR/package-revs.txt" | sort -u > "$TEMP_DIR/unique-repo-revs.txt"
log "Unique repos written to: $TEMP_DIR/unique-repo-revs.txt"
log "Downloading cabal files from repos to: $TEMP_DIR/repos/"
mkdir "$TEMP_DIR/repos"
while IFS= read -r line; do
  repo=$(echo "$line" | cut -d' ' -f1)
  revision=$(echo "$line" | cut -d' ' -f2)
  log "- Downloading \"$repo\" (rev $revision)..."
  dir=$(scripts/fetch-github-cabal-files.sh "$repo" "$revision")
  log "Moving to: $TEMP_DIR/repos/$revision"
  mv "$dir" "$TEMP_DIR/repos/$revision"
done < "$TEMP_DIR/unique-repo-revs.txt"
echo "$TEMP_DIR"
