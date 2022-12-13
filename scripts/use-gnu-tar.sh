#!/usr/bin/env bash

export DATE="date"
export TAR="tar"

if [[ "$(uname -s)" == "Darwin" ]]; then
  if [[ "$(which date)" == "/bin/date" ]]; then
    export DATE="gdate"
  fi
  if [[ "$(which tar)" == "/usr/bin/tar" ]]; then
    export TAR="gtar"
  fi
fi
