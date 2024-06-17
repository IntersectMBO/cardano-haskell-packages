#!/usr/bin/env bash


usage() {
    echo "This script generates a dependency graph among the packages in"
    echo "the CHaP repository. It may have inaccuracies but it is meant to" 
    echo "serve as a map and to be easy and quick to generate."
    echo -e
    echo "Usage: $0 [{-p <path_to_directory>|-h>}]"
    echo "  -p <path_to_directory>  Specify the path to the directory."
    echo "  -h                      Display this help message."
    exit 1
}

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

declare -A packages 
declare -A repos
declare -A versions
declare -A cabal_files
declare -A dependencies

# Function to add an element to the set of packages
add_to_packages() {
    local package
    package="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
    local repo
    repo="$(echo "$2" | tr '[:upper:]' '[:lower:]')"
    local version="$3"
    local cabal_file="$4"
    if [[ -v packages["$package"] ]]; then
        # Project already exists, compare versions
        if is_version_more_recent "$version" "${versions[$package]}"; then
            # Update repo, revision, and version
            repos["$package"]="$repo"
            versions["$package"]="$version"
            cabal_files["$package"]="$cabal_file"
        fi
    else
        # Add new package
        packages["$package"]=1
        repos["$package"]="$repo"
        versions["$package"]="$version"
        cabal_files["$package"]="$cabal_file"
    fi
}

# Function to check if an element is in the set of packages
is_in_set() {
    local element="$1"
    if [[ -v packages["$element"] ]]; then
        return 0 # Element found
    else
        return 1 # Element not found
    fi
}

# Check for arguments
if [ "$#" -eq 0 ]; then
    # No arguments, fetch cabal files
    echo "Fetching cabal files, this can take some minutes..."
    DIR="$(scripts/fetch-all-cabal-files.sh)"
    if [ -z "$DIR" ]; then
        echo "Failed to fetch cabal files."
        exit 1
    fi
    echo "Fetched cabal files to directory: $DIR"
elif [ "$#" -eq 2 ] && [ "$1" == "-p" ]; then
    # Path provided as an argument
    DIR="$2"
elif [ "$#" -eq 1 ] && [ "$1" == "-h" ]; then
    # Help flag provided
    usage
else
    # Invalid usage
    usage
fi

# Check if the directory exists
if [ ! -d "$DIR" ]; then
    echo "Error: Directory '$DIR' does not exist."
    exit 1
fi

# Now we generate the dependency graph
echo "Processing files in directory: $DIR"

# First we create a set of the packages in CHaP and look for latest versions
while IFS= read -r line; do
  repo=$(echo "$line" | cut -d' ' -f1)
  version=$(echo "$line" | cut -d' ' -f2)
  revision=$(echo "$line" | cut -d' ' -f3)
  package=$(echo "$line" | cut -d' ' -f4)
  add_to_packages "$(basename "$(ls "$DIR"/repos/"$revision"/"$package"/*.cabal)" .cabal)" "$repo" "$version" "$(ls "$DIR"/repos/"$revision"/"$package"/*.cabal)"
done < "$DIR/package-revs.txt"

# Sort packages by repo and extract dependency list 
echo "Creating package list sorted by repo in: $DIR/repo_package_cabal.txt"
rm -f "$DIR/repo_package_cabal_unordered.txt"
for package in "${!packages[@]}"; do
    echo "${repos[$package]} $package ${cabal_files[$package]}" >> "$DIR/repo_package_cabal_unordered.txt"
    cabal_file=${cabal_files[$package]}
    if [[ -f "$cabal_file" ]]; then
      package_deps=$("scripts/depencencies-from-cabal-file.sh" "$cabal_file" | sort -u)
      dependencies["$package"]=$(echo "$package_deps" | tr '\n' ' ')
    fi 
done
sort "$DIR/repo_package_cabal_unordered.txt" > "$DIR/repo_package_cabal.txt"
rm -f "$DIR/repo_package_cabal_unordered.txt"

# Now we generate the dot graph 
DOT_FILE="$DIR/dependencies.dot"
echo "Generating dot dependency graph in: $DOT_FILE"
rm -f "$DOT_FILE"

{
  echo "digraph dependencies {"
  echo "  rankdir = \"LR\";"
  echo "  graph [pad=\"0.5\", ranksep=\"3\", nodesep=\"0.5\", fontsize=\"14\", fontname=\"Verdana\"];"
  echo "  splines = \"false\";"
  echo "  node [shape=rectangle fontsize=14 fontname=\"Verdana\" style=\"filled\"];"

  # Cluster by repository
  last_repo=""
  while IFS=  read -r line; do
    repo=$(echo "$line" | cut -d' ' -f1)
    package=$(echo "$line" | cut -d' ' -f2)
    # If this is the start of a new cluster
    if [[ "$repo" != "$last_repo" ]]; then
      # If it's not the first cluster, print end of the previous cluster
      if [[ -n "$last_repo" ]]; then
        echo "  }"
      fi
      # Print beginning of the new cluster
      repo_sanitized=$(echo "$repo" | tr '/' '_' | tr '-' '_')
      echo "  subgraph cluster_$repo_sanitized {"
      echo "    bgcolor = lightblue;"
      echo "    style = filled;"
      echo "    label = <<FONT FACE=\"Verdana\"><B>$repo</B></FONT>>;"
    fi
    echo "    \"$package\";"
    last_repo="$repo"
  done < "$DIR/repo_package_cabal.txt"
  # Print end of the last cluster if there was one
  if [[ -n "$last_repo" ]]; then
    echo "  }"
  fi

  while IFS=  read -r line; do
    repo=$(echo "$line" | cut -d' ' -f1)
    package=$(echo "$line" | cut -d' ' -f2)

    for dep in ${dependencies[$package]}; do
      # Only print if it is in the set
      if is_in_set "$dep"; then
        # Only print if it is not auto dependency
        if [[ "$dep" != "$package" ]]; then
          echo "  \"$package\" -> \"$dep\";"
        fi
      fi
    done

  done < "$DIR/repo_package_cabal.txt"

  echo "}"

} > "$DOT_FILE"


