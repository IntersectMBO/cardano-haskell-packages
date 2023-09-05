#!/usr/bin/env bash

# Gets the latest package versions from the build repository metadata and emits them as TSV

REPO=$1

jq -r 'group_by(."pkg-name") | .[] | max_by(."pkg-version") | [."pkg-name", ."pkg-version"] | @tsv' < "$REPO/foliage/packages.json"
