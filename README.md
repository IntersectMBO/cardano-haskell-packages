# Cardano Haskell package repository

This git repository contains the metadata used to create a
Cabal package repository available at https://input-output-hk.github.io/cardano-haskell-package-repo/ .

The purpose of this package repository is to contain all the Haskell 
packages used by the Cardano open-source project which are not on
Hackage.

If you're here because you need to add a new version of your package, you
probably want to read the section on [adding a package from GitHub](#-from-github).

## What is a Cabal package repository?

A package repository is essentially a mapping from package name and version
to the source distribution for the package. Most Haskell programmers will be
familiar with the package repository hosted on Hackage, which is enabled
by default in Cabal.

However, Cabal supports the use of _additional_ package repositories.
This is convenient for users who can't or don't want to put their packages
on Hackage.

## How to use the package repository

To use the package repository from cabal, add the following lines to your
`cabal.project` file:

```
repository cardano-haskell-package-repo
  url: https://input-output-hk.github.io/cardano-haskell-package-repo/
  secure: True
  root-keys:
    3e0cce471cf09815f930210f7827266fd09045445d65923e6d0238a6cd15126f
    443abb7fb497a134c343faf52f0b659bd7999bc06b7f63fa76dc99d631f9bea1
    a86a1f6ce86c449c46666bda44268677abf29b5b2d2eb5ec7af903ec2f117a82
    bcec67e8e99cabfa7764d75ad9b158d72bfacf70ca1d0ec8bc6b4406d1bf8413
    c00aae8461a256275598500ea0e187588c35a5d5d7454fb57eac18d9edb86a56
    d4a35cd3121aa00d18544bb0ac01c3e1691d618f462c46129271bccf39f7e8ee
  key-threshold: 3
```

The package repository will be understood by cabal, and can be updated with `cabal update`.

The `index-state` for the package repository can also be pinned in as usual:

```
index-state: cardano-haskell-package-repo 2022-08-25T00:00:00Z
```

### ... with haskell.nix

To use the package repository with `haskell.nix`, do the following:

1. Add the package repository to your `cabal.project` as above.
2. Setup a fetcher for the package repository. The easiest way is to use a flake input, such as:
```
inputs.cardanoHaskellPackageRepo = {
  url = "github:input-output-hk/cardano-haskell-package-repo?ref=repo";
  flake = false;
};
```
3. Add the fetched input to the `inputMap` argument of `cabalProject`, like this:
```
cabalProject {
  ...
  inputMap = { "https://input-output-hk.github.io/cardano-haskell-package-repo" = cardanoHaskellPackageRepo; };
}
```

When you want to update the state of the package repository, you can simply update the flake input
(in the example above you would run `nix flake lock --update-input cardanoHaskellPackageRepo`).

## How to add a new package (or package version) to the repository 

Package versions are defined using metadata files `_sources/$pkg_name/$pkg_version/meta.toml`,
which you can create directly. The metadata files have the following format:

```toml
# REQUIRED timestamp at which the package appears in the index
timestamp = 2022-03-29T06:19:50+00:00
# REQUIRED URL pointing to the source code tarball (not decessarily a sdist)
url = 'https://github.com/input-output-hk/ouroboros-network/tarball/fa10cb4eef1e7d3e095cec3c2bb1210774b7e5fa'
# OPTIONAL subdirectory inside the tarball where the package is located
subdir = 'typed-protocols'
```

NOTE: When adding a package, it is important to use a timestamp that is
greater than any other timestamp in the index. Indeed, cabal users rely on
the changes to the repository index to be append-only. A non append-only
change to the package index would change the repository index state as
pinned by `index-state`, breaking reproducibility.

Using the current date and time (e.g. `date --utc +%Y-%m-%dT%H:%M:%SZ`)
works alright but if you are sending a PR you need to consider the
possibility that another developer has inserted a new (greater) timestamp
before your PR got merged. We have CI check that prevents this from
happening, and we enforce FF-only merges.

### ... from GitHub

There is a convenience script `./scripts/add-from-github.sh` to simplify
adding a package from a GitHub repository.

```console
$ ./scripts/add-from-github.sh
Usage: ./scripts/add-from-github.sh REPO_URL REV [SUBDIR...]
```

The script will:

1. Find the cabal files in the repo (either at the root or in the specified subdirectories)
2. Obtain package names and versions from the cabal files
3. Create the corresponding `meta.toml` files
4. Prepopulate a canned commit message in `COMMIT_MSG.txt`

## Help!

If you have trouble, open an issue, or contact the maintainers:

- Andrea Bedini (andrea.bedini@iohk.io)
- Michael Peyton Jones (michael.peyton-jones@iohk.io)
