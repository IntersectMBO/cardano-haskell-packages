#! /usr/bin/env bash

# Use gnu-tar and gnu-date regardless of whether the OS is Linux
# or BSD-based.  The correct command will be assigned to TAR and DATE
# variables.
source "$(dirname "$(which "$0")")/use-gnu-tar.sh"

# for some reason you can't just put a heredoc in a variable...
read -r -d '' USAGE << EOF
check-archive-extension.sh OLD_ARCHIVE NEW_ARCHIVE
  Checks whether NEW_ARCHIVE is an extension of OLD_ARCHIVE. That means
  a) all the entries in OLD_ARCHIVE are in NEW_ARCHIVE
  b) all the new entries in NEW_ARCHIVE have later timestamps than all
     the entries in OLD_ARCHIVE

  This is sensitive to file contents in that it checks their sizes. In
  theory you could defeat this with a file that has the exact same size
  but different contents, but that's obscure and this isn't intended to
  be robust to malicious users.
EOF

if [ "$#" == "0" ]; then
	echo "$USAGE"
	exit 1
fi

OLD_INDEX_TAR=$1
NEW_INDEX_TAR=$2

# Byte-wise comparison
# The basic idea is to check whether the two files are byte-wise identical, up
# to the end of the length of the first file. That shows that the first file is
# a prefix of the second file.
#
# But tar archives are a list of entries terminated by two 512-byte blocks of zeros,
# so to compare the whole content of the old index, we compare up to the length
# minus the zero blocks.

OLD_INDEX_BYTES=$(wc -c < $OLD_INDEX_TAR)
OLD_INDEX_BYTES_TRIMMED="$(($OLD_INDEX_BYTES-1024))"
BYTE_DIFF=$(cmp -n "$OLD_INDEX_BYTES_TRIMMED" "$OLD_INDEX_TAR" "$NEW_INDEX_TAR")

if [ $? = 0 ]
then
  echo "Old archive is a byte-wise prefix of the new archive"
  exit 0
else
  echo "$BYTE_DIFF"
  echo "ERROR: old archive is not a byte-wise prefix of the new archive, looking for differences"
fi

# Output looks like this:
# -rw-r--r-- foliage/foliage  6976 2022-10-25 18:33 network-mux/0.1.0.1/network-mux.cabal
# So fields 4 and 5 are the date and the time
OLD_LISTING=$("$TAR" -tvf "$OLD_INDEX_TAR" | sort -k4,5)
NEW_LISTING=$("$TAR" -tvf "$NEW_INDEX_TAR" | sort -k4,5)

DIFF=$(diff <(echo "$OLD_LISTING") <(echo "$NEW_LISTING"))

if [ $? = 0 ]
then
  echo "Archive listings are identical"
  exit 1
fi

NEW_INDEX_ONLY=$(echo "$DIFF" | grep -P "^>")
OLD_INDEX_ONLY=$(echo "$DIFF" | grep -P "^<")

if [[ ! -z "$OLD_INDEX_ONLY" ]]; then
  echo "ERROR: some entries exist only in the old index"
  echo "$OLD_INDEX_ONLY"
  exit 1
else
  echo "All listing differences are in the new index"
  echo "$NEW_INDEX_ONLY"
fi

LAST_OLD_ENTRY=$(echo "$OLD_LISTING" | tail -n1)
# Take the first thing that appears only in the new, cut out the ">" marker 
# Note: this cannot be empty since:
# 1. The diff was not empty
# 2. The diff on the old side was empty
# therefore the diff on the new side must be non-empty
FIRST_ACTUALLY_NEW_ENTRY=$(echo "$NEW_INDEX_ONLY" | head -n1 | cut -f"2-" -d' ')

function getDate (){
  echo "$1" | tr -s ' ' | cut -f4,5 -d' ' | tr ' ' '-'
}

LAST_OLD_DATE=$(getDate "$LAST_OLD_ENTRY")
FIRST_ACTUALLY_NEW_DATE=$(getDate "$FIRST_ACTUALLY_NEW_ENTRY")


# Standard string comparison will do the job here, because
# we're comparing dates in the format YYYY-MM-DD-HH:MM!
if [[ $LAST_OLD_DATE > $FIRST_ACTUALLY_NEW_DATE ]]; then
  echo "ERROR: Last old entry is newer than first new entry"
  echo "Last old entry:"
  echo "$LAST_OLD_ENTRY"
  echo "First new entry:"
  echo "$FIRST_ACTUALLY_NEW_ENTRY"
  exit 1
elif [[ $LAST_OLD_DATE = $FIRST_ACTUALLY_NEW_DATE ]]; then
  echo "The first new entry has the same timestamp as the last old entry"
  echo "This may mean that they are not ordered correctly since foliage sorts by timestamp only"
  echo "Last old entry:"
  echo "$LAST_OLD_ENTRY"
  echo "First new entry:"
  echo "$FIRST_ACTUALLY_NEW_ENTRY"
  exit 1
else 
  echo "All new entries are strictly newer than the last old entry"
fi

echo "Could not ascertain the reason for the difference between the archives!"
exit 1
