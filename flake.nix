{
  description = "Metadata for Cardano's Haskell package repository";

  inputs = {
    nixpkgs.follows = "haskell-nix/nixpkgs";
    flake-utils.follows = "haskell-nix/flake-utils";

    foliage = {
      url = "github:andreabedini/foliage";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.haskell-nix.follows = "haskell-nix";
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
    # The foliage flake only works on this system, so we are stuck with it too
    flake-utils.lib.eachSystem [ "x86_64-linux" ]
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

          compilers = [ "ghc8107" "ghc926" ];

          builder = import ./nix/builder.nix { inherit pkgs CHaP; };
          chap-meta = import ./nix/chap-meta.nix { inherit pkgs CHaP; };

          smokeTestPackages = [ 
            "plutus-ledger-api" 
            "cardano-ledger-api" 
            "ouroboros-network" 
            "ouroboros-consensus-cardano" 
            "cardano-api" 
            "cardano-node" 
            ];
          # using intersectAttrs like this is a cheap way to throw away everything with keys not in
          # smokeTestPackages
          smokeTestPackageVersions = builtins.intersectAttrs (lib.genAttrs smokeTestPackages (pkg: {})) chap-meta.chap-package-latest-versions;
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

          # { ghc8107 = { foo = { X.Y.Z = <derivation>; ... }; ...}; ... }
          haskellPackages = 
            let
              derivations = compiler: (lib.mapAttrs 
                (name: versions: (lib.genAttrs versions (version: builder compiler name version))) 
                chap-meta.chap-package-versions);
            in
            lib.genAttrs compilers derivations;

          # The standard checks: build all the smoke test packages
          checks = 
            # We use recurseIntoAttrs so flattenTree will flatten it back out again.
            let 
              derivations = compiler: lib.recurseIntoAttrs (lib.mapAttrs (name: version: builder compiler name version) smokeTestPackageVersions);
              # A nested tree of derivations containing all the smoke test packages for all the compiler versions
              perCompilerDerivations = lib.recurseIntoAttrs (lib.genAttrs compilers derivations);
              # cardano-node/cardano-api can't build on 9.2 yet
              # TODO: work out a better way of doing these exclusions
              toRemove = [ (lib.setAttrByPath [ "ghc926" "cardano-api" ] null) (lib.setAttrByPath [ "ghc926" "cardano-node" ] null) ];
              filtered = builtins.foldl' lib.recursiveUpdate perCompilerDerivations toRemove;
            in flake-utils.lib.flattenTree filtered;

          hydraJobs = checks;
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
