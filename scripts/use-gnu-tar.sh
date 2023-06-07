#!/usr/bin/env bash

export TAR="tar"

if [[ "$(uname -s)" == "Darwin" ]]; then
  if [[ "$(which tar)" == "/usr/bin/tar" ]]; then
    export TAR="gtar"
  fi
fi
