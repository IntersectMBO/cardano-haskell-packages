# Run from the root

BUILT_REPO=$1
COMPILER_NIX_NAME=$2
PKGNAME=$3
VERSION=$4

# TODO: nicer interface, easier to test lots of different packages

# This ugliness is apparently the best way to run a function from a flake today,
# taken from https://github.com/NixOS/nix/issues/5663#issuecomment-1278505018
nix build --impure --expr "(builtins.getFlake ''git+file://$PWD?shallow=1'').functions.x86_64-linux.build-pkg-job { built-repo = $BUILT_REPO; compiler-nix-name = ''$COMPILER_NIX_NAME''; pkgname = ''$PKGNAME''; version = ''$VERSION''; }"
