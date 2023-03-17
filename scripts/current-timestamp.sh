#!/usr/bin/env bash

# Use gnu-tar and gnu-date regardless of whether the OS is Linux
# or BSD-based.  The correct command will be assigned to TAR and DATE
# variables.
source "$(dirname "$(which "$0")")/use-gnu-tar.sh"

"$DATE" --utc +%Y-%m-%dT%H:%M:%SZ
