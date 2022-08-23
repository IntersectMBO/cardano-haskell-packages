# Metadata for Haskell package repository

This git repository contains the metadata used to create the internal
Hackage package repository available at https://...

To use that repository from cabal, add the following lines to your
`cabal.project` file:

```
repository iog-hackage
  url: https://...
  secure: True
  root-keys:
    ...
    ...
    ...
  key-threshold: 3
```

## Including a new package (or package version)

To add a new package (or package version) to the repository, all you have
to do is to add a file `_sources/$pkg_name/$pkg_version/meta.toml` with the
following format:

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
happening.

## Including a new package from GitHub

We include a convenience script `./scripts/add-from-github.sh` to simplify
adding a package from a GitHub repository.

```
$ ./scripts/add-from-github.sh
Usage: ./scripts/add-from-github.sh REPO_URL REV [SUBDIR...]
```

The script will:

- Find the cabal files in the repo (either at the root or in the specified subdirectories)
- Obtain package names and versions from the cabal files
- Create the corresponding `meta.toml` files
- Prepopulate a canned commit message in `COMMIT_MSG.txt`

# Help!

- Andrea Bedini (andrea.bedini@iohk.io)
- Michael Peyton Jones (michael.peyton-jones@iohk.io)
