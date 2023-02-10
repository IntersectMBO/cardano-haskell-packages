#!/usr/bin/env bash

# Run from the root

BUILT_REPO=$1
COMPILER_NIX_NAME=$2
PKG_LIST=$3

mkNixExpr () {
  echo "["
  cat "$PKG_LIST" | while read -r line 
  do
    # convert into an array splitting on whitespace
    pkgparts=($line)
    PKGNAME=${pkgparts[0]}
    VERSION=${pkgparts[1]}
    echo "{ built-repo = $BUILT_REPO; compiler-nix-name = ''$COMPILER_NIX_NAME''; pkgname = ''$PKGNAME''; version = ''$VERSION''; }"
  done 
  echo "]"
}

# This ugliness is apparently the best way to run a function from a flake today,
# taken from https://github.com/NixOS/nix/issues/5663#issuecomment-1278505018
nix build --impure --expr "(builtins.getFlake ''git+file://$PWD?shallow=1'').functions.x86_64-linux.build-pkgs-job $(mkNixExpr)"
