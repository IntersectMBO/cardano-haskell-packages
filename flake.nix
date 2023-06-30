{
  description = "Metadata for Cardano's Haskell package repository";

  inputs = {
    nixpkgs.follows = "haskell-nix/nixpkgs";
    flake-utils.follows = "haskell-nix/flake-utils";

    foliage = {
      url = "github:input-output-hk/foliage";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.haskell-nix.follows = "haskell-nix";
      inputs.hackage-nix.follows = "hackage-nix";
      inputs.flake-utils.follows = "flake-utils";
    };

    haskell-nix = {
      url = "github:input-output-hk/haskell.nix";
      inputs.hackage.follows = "hackage-nix";
    };

    hackage-nix = {
      url = "github:input-output-hk/hackage.nix";
      flake = false;
    };

    CHaP = {
      url = "github:input-output-hk/cardano-haskell-packages?ref=repo";
      flake = false;
    };

    iohk-nix = {
      url = "github:input-output-hk/iohk-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, foliage, haskell-nix, CHaP, iohk-nix, ... }:
    # The foliage flake only works on linux, so the other systems won't actually work
    # until https://github.com/andreabedini/foliage/issues/53 is fixed, but we might
    # as well leave the more general code in here.
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            inherit (haskell-nix) config;
            overlays = [
              haskell-nix.overlay
              iohk-nix.overlays.crypto
            ];
          };
          inherit (pkgs) lib;

          # type CompilerName = String
          # compilers :: [CompilerName]
          compilers = [ "ghc8107" "ghc927" ];

          builder = import ./nix/builder.nix { inherit pkgs CHaP; };
          chap-meta = import ./nix/chap-meta.nix { inherit pkgs CHaP; };

          # type PkgSet = Map CompilerName (Map PkgName (Map PkgVerison Derivation))
          # pkgVersionsToPkgSet :: PkgVersions -> PkgSet
          pkgVersionsToPkgSet = pkg-versions:
            # We use recurseIntoAttrs so flattenTree will flatten it back out again.
            let
              derivations = compiler: lib.recurseIntoAttrs (lib.mapAttrs
                (name: versions: (lib.recurseIntoAttrs (lib.genAttrs versions (version: builder compiler name version))))
                pkg-versions);
              # A nested tree of derivations containing all the packages for all the compiler versions
              perCompilerDerivations = lib.recurseIntoAttrs (lib.genAttrs compilers derivations);
              # cardano-node/cardano-api can't build on 9.2 yet
              # TODO: work out a better way of doing these exclusions
              toRemove = [
                (lib.setAttrByPath [ "ghc927" "cardano-api" ] null)
                (lib.setAttrByPath [ "ghc927" "cardano-node" ] null)
                (lib.setAttrByPath [ "ghc927" "plutus-ledger" ] null)
                (lib.setAttrByPath [ "ghc927" "marlowe-cardano" ] null)
                (lib.setAttrByPath [ "ghc927" "marlowe-chain-sync" ] null)
                (lib.setAttrByPath [ "ghc927" "marlowe-client" ] null)
                (lib.setAttrByPath [ "ghc927" "marlowe-protocols" ] null)
                (lib.setAttrByPath [ "ghc927" "marlowe-runtime" ] null)
                (lib.setAttrByPath [ "ghc927" "marlowe-runtime-web" ] null)
                (lib.setAttrByPath [ "ghc927" "marlowe-test" ] null)
                (lib.setAttrByPath [ "ghc927" "quickcheck-contractmodel" ] null)
              ];
              filtered = builtins.foldl' lib.recursiveUpdate perCompilerDerivations toRemove;
            in
            filtered;

          allPkgVersions = chap-meta.chap-package-versions chap-meta.chap-package-meta;

          smokeTestPackages = [
            "plutus-ledger-api"
            "cardano-ledger-api"
            "ouroboros-network"
            "ouroboros-consensus-cardano"
            "cardano-api"
            "cardano-node"
            # from plutus-apps
            "plutus-ledger"
          ];

          # using intersectAttrs like this is a cheap way to throw away everything with keys not in
          # smokeTestPackages
          smokeTestPkgVersions =
            builtins.intersectAttrs
              (lib.genAttrs smokeTestPackages (pkg: { }))
              (chap-meta.chap-package-latest-versions chap-meta.chap-package-meta);

          # use a self + path reference to ensure this runs in the context of the
          # whole flake source, so can see the other scripts
          update-chap-deps = pkgs.writeShellScriptBin "update-chap-deps" ''
            ${self + "/scripts/update-chap-deps.sh"} ${CHaP} $@
          '';
        in
        rec {
          devShells.default = with pkgs; mkShellNoCC {
            name = "cardano-haskell-packages";
            buildInputs = [
              bash
              coreutils
              curlMinimal.bin
              gitMinimal
              gnutar
              foliage.packages.${system}.default
            ];
          };

          haskellPackages = pkgVersionsToPkgSet allPkgVersions;
          smokeTestPackages = pkgVersionsToPkgSet smokeTestPkgVersions;

          packages = flake-utils.lib.flattenTree haskellPackages // {
            inherit update-chap-deps;

            allPackages = pkgs.releaseTools.aggregate {
              name = "all-packages";
              constituents = builtins.attrValues (flake-utils.lib.flattenTree haskellPackages);
            };

            allSmokeTestPackages = pkgs.releaseTools.aggregate {
              name = "all-smoke-test-packages";
              constituents = builtins.attrValues (flake-utils.lib.flattenTree smokeTestPackages);
            };
          };

          # The standard checks: build all the smoke test packages
          checks = flake-utils.lib.flattenTree smokeTestPackages;

          hydraJobs = lib.optionalAttrs (!builtins.elem system [
            "aarch64-linux" # not supported by our Hydra instance
          ]) checks;
        });

  nixConfig = {
    extra-substituters = [
      "https://cache.iog.io"
      "https://foliage.cachix.org"
      "https://cache.zw3rk.com"
    ];
    extra-trusted-substituters = [
      # If you have a nixbuild.net SSH key set up, you can pull builds from there
      # by using '--extra-substituters ssh://eu.nixbuild.net' manually, otherwise this
      # does nothing
      "ssh://eu.nixbuild.net"
    ];
    extra-trusted-public-keys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "foliage.cachix.org-1:kAFyYLnk8JcRURWReWZCatM9v3Rk24F5wNMpEj14Q/g="
      "loony-tools:pr9m4BkM/5/eSTZlkQyRt57Jz7OMBxNSUiMC4FkcNfk="
      "nixbuild.net/smart.contracts@iohk.io-1:s2PhQXWwsZo1y5IxFcx2D/i2yfvgtEnRBOZavlA8Bog="
    ];
    allow-import-from-derivation = true;
  };
}
