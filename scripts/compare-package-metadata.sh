#!/usr/bin/env bash

OLD=$(cat "$1")
NEW=$(cat "$2")
COMBINED="{ \"old\": $OLD, \"new\": $NEW }"

echo "$COMBINED" | jq '.new-.old'
