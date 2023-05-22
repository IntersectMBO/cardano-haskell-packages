# Contributing to `cardano-haskell-packages`

IMPORTANT: this document is about contributing to the project as a "maintainer"
rather than a "user", i.e. working on the infrastructure, not adding package
versions etc. "User" workflows are covered in the README, as well as many other
generally important topics, so read that first.

## Core maintainers

The core maintainers of the project are the members of the 
@input-output-hk/cardano-haskell-packages-trustees Github team.

The responsibilities of the maintainers are both maintaining the project's
infrastructure, but also keeping the package repository healthy. That means

- Keeping an eye on user behaviour in case they get themselves into a mess.
- Fixing things should we somehow end up in a broken state.
- Reviewing contributions that lack other reviewers.
    - This includes making decisions about whether e.g. it is okay to include
      a patched version of a Hackage package.

The maintainers do _not_ have any authority over package maintainers when it
comes to deciding how to release, revise, or deprecate their own packages, 
although it may be a good idea to advise them.

The goal with the infrastructure should be to make it easy for users to 
use, and hard for them to do the wrong thing. Ideally the project maintainers
should not have to get involved often, if at all.

## Dev environment

The only tool we really rely on is `foliage`. This is provided by the
Nix shell, which can be accessed with `nix develop`.

## CI

The most important piece of infrastructure is the CI. See README for a
high-level overview of what it does. The workflow should be fairly
self-explanatory.

### Building packages

We rely on Nix to build packages in CI. At the moment we trigger this
from GHA and use nixbuild.net to provide builders.

The reason we do this is that we need a newly built repository in
order to build the packages, and we cannot currently do that purely in
Nix. So we build it "impurely" in GHA, and then trigger the Nix build
after that.

Otherwise we would probably use Hydra for building packages, which 
would be more convenient.

### nixbuild.net

nixbuild.net requires an access token to use. At the moment we are
using a token issued to @michaelpj. 

For any larger issues with nixbuild.net, contact @shlevy.
