#! /usr/bin/env bash

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

# Output looks like this:
# -rw-r--r-- foliage/foliage  6976 2022-10-25 18:33 network-mux/0.1.0.1/network-mux.cabal
# So fields 4 and 5 are the date and the time
OLD_LISTING=$(tar -tvf "$OLD_INDEX_TAR" | sort -k4,5)
NEW_LISTING=$(tar -tvf "$NEW_INDEX_TAR" | sort -k4,5)

DIFF=$(diff <(echo "$OLD_LISTING") <(echo "$NEW_LISTING"))

if [ $? = 0 ]
then
  echo "Archives are identical"
  exit 0
fi

NEW_INDEX_ONLY=$(echo "$DIFF" | grep -P "^>")
OLD_INDEX_ONLY=$(echo "$DIFF" | grep -P "^<")

if [[ ! -z "$OLD_INDEX_ONLY" ]]; then
  echo "ERROR: some entries exist only in the old index"
  echo "$OLD_INDEX_ONLY"
  exit 1
else
  echo "All differences are in the new index"
  echo "$NEW_INDEX_ONLY"
fi

LAST_OLD_ENTRY=$(echo "$OLD_LISTING" | tail -n1)
# Take the first thing taht appears only in the new, cut out the ">" marker 
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
else 
  echo "All new entries are newer than the last old entry"
fi

