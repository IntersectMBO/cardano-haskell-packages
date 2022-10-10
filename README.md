# Cardano Haskell package repository ("CHaP")

This git repository contains the metadata used by [`foliage`](https://github.com/andreabedini/foliage)
to create a Cabal package repository available at https://input-output-hk.github.io/cardano-haskell-packages/ .

The purpose of this package repository ("CHaP") is to contain all the Haskell
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

### Cabal package repositories and `source-repository-package`

Using `source-repository-package` stanzas is another common way of getting dependencies
that are not on Hackage. Both have their place: CHaP gives us proper versioning
and simpler setup, `source-repository-package`s are useful for ad-hoc use of
patched or pre-release versions.

Crucially, additional Cabal pacakge repositories like CHaP and `source-repository-package`
stanzas are _compatible_ and _`source-repository-package`s always win_. That is,
they interact in the same way as Hackage and `source-repository-package`s do. This gives us
behaviour that we want: ad-hoc `source-repository-package` stanzas will override
packages from Hackage _or_ CHaP.

## How to use CHaP

To use CHaP from cabal, add the following lines to your
`cabal.project` file:

```
repository cardano-haskell-packages
  url: https://input-output-hk.github.io/cardano-haskell-packages
  secure: True
  root-keys:
    3e0cce471cf09815f930210f7827266fd09045445d65923e6d0238a6cd15126f
    443abb7fb497a134c343faf52f0b659bd7999bc06b7f63fa76dc99d631f9bea1
    a86a1f6ce86c449c46666bda44268677abf29b5b2d2eb5ec7af903ec2f117a82
    bcec67e8e99cabfa7764d75ad9b158d72bfacf70ca1d0ec8bc6b4406d1bf8413
    c00aae8461a256275598500ea0e187588c35a5d5d7454fb57eac18d9edb86a56
    d4a35cd3121aa00d18544bb0ac01c3e1691d618f462c46129271bccf39f7e8ee
```

The package repository will be understood by cabal, and can be updated with `cabal update`.

The `index-state` for the package repository can also be pinned in as usual:

```
index-state: cardano-haskell-packages 2022-08-25T00:00:00Z
```

### ... with haskell.nix

To use CHaP with `haskell.nix`, do the following:

1. Add the package repository to your `cabal.project` as above.
2. Setup a fetcher for the package repository. The easiest way is to use a flake input, such as:
```
inputs.CHaP = {
  url = "github:input-output-hk/cardano-haskell-packages?ref=repo";
  flake = false;
};
```
3. Add the fetched input to the `inputMap` argument of `cabalProject`, like this:
```
cabalProject {
  ...
  inputMap = { "https://input-output-hk.github.io/cardano-haskell-packages" = CHaP; };
}
```

When you want to update the state of CHaP, you can simply update the flake input
(in the example above you would run `nix flake lock --update-input CHaP`).

If you have CHaP configured correctly, then when you run `cabal build` from inside a `haskell.nix`
shell, you should not see any of the packages in CHaP being built by cabal.
The exception is if you have a `source-repository-package` stanza which overrides a _dependency_ of one
of the packages in CHaP. Then cabal will rebuild them both. If this becomes a problem,
you can consider adding the patched package to CHaP itself,
see [below](#how-do-i-add-a-patched-versions-of-a-hackage-package-to-chap).

## How to add a new package (or package version) to CHaP 

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
Usage add-from-github.sh [-r REVISION] [-v VERSION] REPO_URL REV [SUBDIRS...]

        -r REVISION     adds .0.0.0.0.REVISION to the package version
        -v VERSION      uses VERSION as the package version
```

The script will:

1. Find the cabal files in the repo (either at the root or in the specified subdirectories)
2. Obtain package names and versions from the cabal files
3. Create the corresponding `meta.toml` files
4. Commit the changes to the git repository

You can tell the script to override the package version either by passing
the version explicitly or by adding a "revision number" (see below).

## How do I add a patched versions of a Hackage package to CHaP?

CHaP should mostly contain versions of packages which are _not_ on Hackage.

If you need to patch a version of a package on Hackage, then there are two options:

1. For short lived forks, use a `source-repository-package` stanza by preference.
2. For long-lived forks (because e.g. the maintainer is unresponsive or the patch is large and will take time to upstream), then we can consider releasing a patched version in CHaP.

The main constraint when adding a patched version to CHaP is to be sure that we use a version number that won't ever conflict with a release made by upstream on Hackage.
There are two approaches to doing this:

1. Release the package in CHaP under a different name (for the fork).
This is very safe, but may not be possible if the dependency is incurred via a packge we don't control, as then we can't force it to depend on the renamed package.
2. Release the package under a version that is very unlikely to be used by upstream.
The scheme that we typically use is to take the existing version number, add four zero components and then a patch version, e.g. `1.2.3.4.0.0.0.0.1`.

## How to test changes to CHaP against haskell.nix projects

Sometimes it is useful to test in advance how a new package or a cabal file
revision affect a certain project. If the project uses haskell.nix, one can
follow these steps:

- Make a local checkout of CHaP and make the intended changes
- Build the repository with `nix shell -c foliage build`
- Build the project to test overriding the repository with your local
  version in `_repo`.
  ```bash
  $ nix build --override-input CHaP path:/home/user/cardano-haskell-packages/_repo
  ```
- In particular you can examine the build plan without completing the
  build:
  ```bash
  $ nix build .#cardano-node.project.plan-nix.json \
    --out-link plan.json                           \
    --override-input CHaP path:/home/user/cardano-haskell-packages/_repo
  ```
- Note that you might need to bump the index-state to allow cabal to see
  the changes in the repository.

## What do I do if I want to release a package in CHaP to Hackage?

It's totally fine to release a package in CHaP to Hackage.
The thing to avoid is to have the same package _version_ in both repositories.
The simplest solution is to just make sure to use a higher major version number when you start releasing to Hackage, even if this looks a bit odd.
For example, if CHaP contains `X-1.0` and `X-1.1`, then the first Hackage release should be `X-1.2` or `X-2.0`.

## CI for CHaP 

The CI for CHaP does the following things:

- Checks that the timestamps in the git repository are monotonically increasing through commits.
Along with requiring linear history, this ensures that package repository that we build is always an extension of the previous one.
- Builds the package repository from the metadata using `foliage`.
- Deploys the package repository to the `repo` branch, along with some static web content.

## Creating a repository like CHaP

If you just want or test changes to CHaP, you should make a
fork. If you want to replicate the setup from scratch you can clone [this
template](https://github.com/andreabedini/foliage-template).

## Help!

If you have trouble, open an issue, or contact the maintainers:

- Andrea Bedini (andrea.bedini@iohk.io)
- Michael Peyton Jones (michael.peyton-jones@iohk.io)
