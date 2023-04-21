# Cardano Haskell package repository ("CHaP")

* [All packages](https://input-output-hk.github.io/cardano-haskell-packages/all-packages/).
* [All package versions](https://input-output-hk.github.io/cardano-haskell-packages/all-package-versions/).

IMPORTANT: If you're here because you need to publish a new version of your package, you
probably want to read the section on [adding a package from GitHub](#-from-github).

This is a Cabal package repository ("CHaP") whose purpose is to contain all the Haskell
packages used by the Cardano open-source project which are not on Hackage.

The package repository itself is available [here](https://input-output-hk.github.io/cardano-haskell-packages).
It is built from a [git repository](https://github.com/input-output-hk/cardano-haskell-packages) which
contains the metadata specifying all the package versions. The package repository is built using
[`foliage`](https://github.com/andreabedini/foliage).

## Help!

If you have trouble, open an issue, or contact the trustees: @input-output-hk/cardano-haskell-packages-trustees

## Background 

This section explains some concepts that are useful for understanding and working with CHaP.

### What is a Cabal package repository?

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

Crucially, additional Cabal package repositories like CHaP and `source-repository-package`
stanzas are _compatible_ and _`source-repository-package`s always win_. That is,
they interact in the same way as Hackage and `source-repository-package`s do. This gives us
behaviour that we want: ad-hoc `source-repository-package` stanzas will override
packages from Hackage _or_ CHaP.

## Using CHaP

To use CHaP with cabal, add the following lines to your
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
You must run `cabal update` at least once so cabal can download the package index!

The `index-state` for the package repository can also be pinned as usual. 
You can either just use a single `index-state` for both Hackage and CHaP:

```
index-state: 2022-08-25T00:00:00Z
```

or you can specify a different index-state for each repository:

```
index-state:
  , hackage.haskell.org      2022-12-31T00:00:00Z
  , cardano-haskell-packages 2022-08-25T00:00:00Z
```

Note that a second `index-state` stanza completely ovverides the first, so

```
index-state: 2022-12-31T00:00:00Z
index-state: cardano-haskell-packages 2022-08-25T00:00:00Z
```

would override the index-state for Hackage to HEAD (since HEAD is the default).

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
3. Tell haskell-nix to map the CHaP url to the appropriate nix store path using the `inputMap` argument of one of [haskell.nix project functions](https://input-output-hk.github.io/haskell.nix/reference/library.html#top-level-attributes). Using `cabalProject` this would look like the following:
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

Warning: Haskell.nix cannot parse the `index-state` syntax with multiple
repositories (see [haskell.nix#1869](https://github.com/input-output-hk/haskell.nix/issues/1869)).
You can use the following workaround to appease both Haskell.nix and cabal.

```
-- haskell.nix will parse this (https://github.com/input-output-hk/haskell.nix/issues/1869)
index-state: 2022-12-31T00:00:00Z
-- cabal will overwrite the above with this
index-state:
  , hackage.haskell.org      2022-12-31T00:00:00Z
  , cardano-haskell-packages 2022-08-25T00:00:00Z
```

### Creating a repository like CHaP

If you just want to test changes to CHaP, you should make a
fork. If you want to replicate the setup from scratch you can clone [this template](https://github.com/andreabedini/foliage-template).

## Contributing packages and revisions 

This section explains how to contribute to the main content of CHaP: packages and revisions.
The contribution itself should be [made in a PR](#making-changes).

### Requirements for including a package 

#### Monotonically increasing timestamps

When adding a package, it is important to use a timestamp (see [below](#how-to-add-a-new-package-version))
that is greater than any other timestamp in the index. Indeed, cabal users rely on
the changes to the repository index to be append-only. A non append-only
change to the package index would change the repository index state as
pinned by `index-state`, breaking reproducibility.

This condition is enforced by the CI, and we only allow FF-merges in order to ensure that we are always checking a linear history.

Tips for working with timestamps:
- Most of the scripts will insert timestamps for you, e.g. `./scripts/add-from-github.sh`
- If you have a PR and the timestamps are now too old (e.g. because someone else made a PR in the meantime), then see [below](#dealing-with-timestamp-conflicts) for tips
- If you want to get a suitable timestamp for some other reason, `./scripts/current-timestamp.sh` will produce one

#### No extra build configuration beyond what is given in the cabal file

When downstream users pull a package from CHaP, `cabal` will build it based _only_ on the
information in the cabal file. This means that if your package needs any additional configuration
to build, then it will simply be broken for downstream users unless they replicate that
configuration.

Typical examples of this are anything that you add in `cabal.project`:
- `constraints`
- `allow-newer`
- `source-repository-package`

This is enforced by the CI, which will build newly added packages in PRs. 

### How to add a new package version 

Package versions are defined using metadata files `_sources/$pkg_name/$pkg_version/meta.toml`,
which you can create directly. The metadata files have the following format:

```toml
# REQUIRED timestamp at which the package appears in the index
timestamp = 2022-03-29T06:19:50+00:00
# REQUIRED URL pointing to the source code tarball (not necessarily a sdist)
url = 'https://github.com/input-output-hk/ouroboros-network/tarball/fa10cb4eef1e7d3e095cec3c2bb1210774b7e5fa'
# OPTIONAL subdirectory inside the tarball where the package is located
subdir = 'typed-protocols'
```

#### ... from GitHub

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

### How to add a new package metadata revision 

CHaP supports package metadata revisions just like Hackage. These allow you to provide an edited cabal 
file for a package version. The primary use of this is to tweak the dependency bounds of a package. 
In principle you can change other things too, but this is generally frowned upon.

There is a convenience script for adding a revision to CHaP:
```
$ ./scripts/add-revision.sh _repo PACKAGE_NAME PACKAGE_VERSION
```

You need a [built package repository](#how-to-build-the-cabal-package-repository) in order to use the script.
It will add a new revision and copy the _current_ cabal file in as the revised cabal file.
You can then edit that file and commit the result.

### How to add a patched versions of a Hackage package 

CHaP should mostly contain versions of packages which are _not_ on Hackage.

If you need to patch a version of a package on Hackage, then there are two options:

1. For short lived forks, use a `source-repository-package` stanza by preference.
2. For long-lived forks (because e.g. the maintainer is unresponsive or the patch is large and will take time to upstream), then we can consider releasing a patched version in CHaP.

The main constraint when adding a patched version to CHaP is to be sure that we use a version number that won't ever conflict with a release made by upstream on Hackage.
There are two approaches to doing this:

1. Release the package in CHaP under a different name (for the fork).
This is very safe, but may not be possible if the dependency is incurred via a package we don't control, as then we can't force it to depend on the renamed package.
2. Release the package under a version that is very unlikely to be used by upstream.
The scheme that we typically use is to take the existing version number, add four zero components and then a patch version, e.g. `1.2.3.4.0.0.0.0.1`.

IMPORTANT: if you release a patched package to CHaP, make sure to open an issue about it so we can keep track of which patched packages we have.
Ideally, include the conditions under which we can deprecate it, e.g. "can deprecate either when it's fixed upstream or when package X removes their dependency on it".

### How to update Hackage index used by CHaP

If one of your packages requires a newer version of a package published on Hackage, you will need to run: `nix flake lock --update-input hackage-nix`.
[`hackage.nix`] is automatically updated from Hackage once per day.
If things still don't work because the version of the package is not available you'll need either wait for the automatic update or make a PR to [`hackage.nix`] first and then rerun the above command.

### Releasing CHaP packages to Hackage

It's totally fine to release a package in CHaP to Hackage.
The thing to avoid is to have the same package _version_ in both repositories.
The simplest solution is to just make sure to use a higher major version number when you start releasing to Hackage, even if this looks a bit odd.
For example, if CHaP contains `X-1.0` and `X-1.1`, then the first Hackage release should be `X-1.2` or `X-2.0`.

## Building and testing CHaP

For most contributors this section is not going to be necessary, and you can rely on the CI. 

However if you are making a large number of changes (e.g. many revisions), it can be useful to test your work before making a PR.

### How to build the Cabal package repository

The Cabal package repository itself is built using the tool `foliage`. `foliage` is available in the Nix dev shell, which you can get into using `nix develop`.

To build the repository, run `foliage build -j 0 --write-metadata`. This will build the repository and put it in `_repo`.

### How to test changes 

Sometimes it is useful to test in advance how a new package or a cabal file
revision affects things.

First of all, [build the repository](#how-to-build-the-cabal-package-repository).
For the rest of this section we will assume the built repository is in 
`/home/user/cardano-haskell-packages/_repo`.

#### ... by building packages with `cabal`

You can test a locally built CHaP with a small test project consisting of just a
`cabal.project` file:

```
-- Give it a different name to avoid cabal confusing it with the 
-- real CHaP
repository cardano-haskell-packages-local
  -- Point this to the *built* repository
  url: file:/home/user/cardano-haskell-packages/_repo
  secure: True
  -- You can skip the root-keys field

-- Add all the packages you want to try building
extra-packages: 
  , cardano-prelude-0.1.0.0
```

You need to tell cabal about the new repository with `cabal update` (you might need to
clear out `~/.cabal/packages/cardano-haskell-packages-local` if  you've been
editing your repository destructively).

Then you can build whatever package version you want with `cabal`:

```bash
$ cabal build cardano-prelude
```

You can troubleshoot a failed build plan using the cabal flags `--constraint`, `--allow-newer` and `--allow-older`. Once you have obtained a working build plan, you should revise you cabal file with appropriate constraints.

#### ... by building packages with Nix

You can build packages from CHaP using Nix like this:

```
nix build 
  --override-input CHaP /home/user/cardano-haskell-packages/_repo
  .#"ghc926/plutus-core/1.1.0.0"
```

This will build all the components of that package version that CHaP cares about, namely libraries and executables (test suites and benchmarks are not built).

We need to use `--override-input` because the CHaP flake relies on a built repository. 
By default it points to a built repository on the main CHaP `repo` branch. 
But if you have just produced your own built repository (see above) then you want to
use that instead, and `--override-input` will let you do that.

#### ... by testing against a haskell.nix project

If you want to test a locally built CHaP against a project that uses CHaP 
via haskell.nix, you can build the project while overriding CHaP
with your local version.

```bash
$ nix build --override-input CHaP path:/home/user/cardano-haskell-packages/_repo
```

Note that you will need to change the `index-state` for `cardano-haskell-packages` 
to be newer than the repository you just built, otherwise cabal will ignore your 
new package versions!

Also, you you can examine the build plan without completing the build:
```bash
$ nix build .#project.plan-nix.json \
	--out-link plan.json \
	--override-input CHaP path:/home/user/cardano-haskell-packages/_repo
```

This is useful if you jsut want to see whether cabal is able to successfully
resolve dependencies and see what versions it picked.

## Making changes 

Changes to CHaP should simply be made using PRs.

### Access control 

CHaP uses `CODEOWNERS` to determine whose approval is needed to release a package. 
The general rules are:

- If a package is clearly owned by a particular team, then set that team as the CODEOWNER.
- Prefer to use GitHub teams over individual accounts wherever possible.
- In the case of patched packages, the owner should be whichever team owns the package that causes the dependency on the package that needs patching.

Generally, use your judgement about what's appropriate.

### CI 

The CI for CHaP does the following things:

- Checks that the timestamps in the git repository are monotonically increasing through commits.
Along with requiring linear history, this ensures that package repository that we build is always an extension of the previous one.
- Builds the package repository from the metadata using `foliage`.
- Builds a small set of packages using the newly built repository.
    - We build with all the major GHC versions we expect to be in use.
    - At the moment we don't build all the packages in the repository, only the latest versions of a fixed set.
- Builds any newly added packages using the newly built repository.
- If on the master branch, deploys the package repository to the `repo` branch, along with some static web content.

### Dealing with timestamp conflicts

Since we require monotonically increasing timestamps, there can be timestamp conflicts if someone else merges a PR with later timestamps than yours.
That means that your PR (once updated from `main`) will now introduce "old" timestamps, which is not allowed.

There are some scripts for dealing with this:
- `./scripts/update-timestamps-in-revision.sh REV` will look at the given revision, find any timestamps that were added in that commit, and make changes to update them to a fresh timestamp.
- `./scripts/update-timestamps-and-fixup.sh REV` will do the same but also commit the changes as a fixup commit. You can either leave these in your PR or get rid of them with `git rebase main --autosquash`

An easy way to run `update-timestamps-and-fixup` on a multi-commit PR is to run `git rebase main --exec "./scripts/update-timestamps-and-fixup.sh HEAD"`.
This will run the script at every step of the rebase on `HEAD` (i.e. the commit you have reached).

[`hackage.nix`]: https://github.com/input-output-hk/hackage.nix
