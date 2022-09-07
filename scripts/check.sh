#!/usr/bin/env bash

set -o errexit
set -o pipefail

convert_timestamp_to_unix_time() {
  date --date "$1" +%s
}

removed_timestamps_in_rev() {
  local rev=$1
  git show -p "$rev" '_sources/*/*/meta.toml' \
  | sed -n -e 's/^-\s*timestamp\s\+=\s\+//p'
}

added_timestamps_in_rev() {
  local rev=$1
  git show -p "$rev" '_sources/*/*/meta.toml' \
  | sed -n -e 's/^+\s*timestamp\s\+=\s\+//p'
}

for rev in $(git rev-list --reverse HEAD); do
  if [[ -n $(removed_timestamps_in_rev "$rev") ]]; then
    echo "A package timestamp has been modified in $rev"
    git diff -p "$rev"
    exit 1
  fi

  mapfile -t timestamps < <(added_timestamps_in_rev "$rev")

  if [[ -n "${timestamps[*]}" ]]; then
    lowest=${timestamps[0]}
    highest=${timestamps[-1]}
    if [[ $lowest == "$highest" ]]; then
      echo "$rev introduced timestamp $highest"
    else
      echo "$rev introduced timestamps between $lowest and $highest"
    fi
    a=$(convert_timestamp_to_unix_time "$lowest")
    b=$(convert_timestamp_to_unix_time "$latest_timestamp")
    if [[ -n $latest_timestamp && $a -le $b ]]; then
      echo "$rev introduces a timestamp $lowest which is not greater that the latest timestamp $latest_timestamp"
      exit 1
    fi
    latest_timestamp=${latest_timestamp:-$highest}
  fi
done
