#!/usr/bin/env bash

declare -A repos

is_version_more_recent() {
  local version1=$1
  local version2=$2

  # Split version numbers into arrays
  IFS='.' read -ra v1_parts <<< "$version1"
  IFS='.' read -ra v2_parts <<< "$version2"

  # Compare version parts
  local i=0
  while [[ $i -lt ${#v1_parts[@]} || $i -lt ${#v2_parts[@]} ]]; do
    local part1="${v1_parts[$i]}"
    local part2="${v2_parts[$i]}"

    # If one part is missing in one of the versions, consider it as zero
    part1=${part1:-0}
    part2=${part2:-0}

    if (( part1 > part2 )); then
      return 0
    elif (( part1 < part2 )); then
      return 1
    fi

    ((i++))
  done

  # If we reached here, versions are equal
  return 1
}

# Find all meta.toml files
while IFS= read -r toml; do
  # Extract information from each meta.toml (we use grep for efficiency)
  repo=$(grep -oP '(?<=repo = ")[^"]+' "$toml")
  rev=$(grep -oP '(?<=rev = ")[^"]+' "$toml")
  subdir=$(grep -oP "(?<=subdir = ')[^']+" "$toml")
  version=$(basename "$(dirname "$toml")")

  # Remove trailing "/" from repo and subdir if it exists
  repo="${repo%/}"
  subdir="${subdir%/}"

  # Sanitise repo and subdir names and convert to lowercase
  repo_sanitized=$(echo "$repo" | tr '/' '_' | tr '[:upper:]' '[:lower:]')
  subdir_sanitized=$(echo "$subdir" | tr '/' '_' | tr '[:upper:]' '[:lower:]')

  # Store information in an associative array
  key="${repo_sanitized}_${subdir_sanitized}"

  # Use associative array to keep track of latest version
  if [[ ! -v "repos[$key]" ]];
  then
    repos[$key]="$repo $version $rev $subdir"
  else
    latestVersion=$(echo "${repos[$key]}" | awk '{print $2}')
    if is_version_more_recent "$version" "$latestVersion";
    then
      repos[$key]="$repo $version $rev $subdir"
    fi
  fi
done < <(find _sources -name "meta.toml")

for key in "${!repos[@]}"; do
  echo "${repos[$key]}"
done


