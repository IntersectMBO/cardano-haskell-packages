#!/usr/bin/env bash

OLD=$(jq -c 'map(del(."forced-version"))' "$1")
NEW=$(cat "$2")
COMBINED="{ \"old\": $OLD, \"new\": $NEW }"

echo "$COMBINED" | jq '.new-.old'
