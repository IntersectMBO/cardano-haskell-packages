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
    let 
      compilers = [ "ghc8107" "ghc926" ];
      smokeTestPackages = [ 
        "cardano-node" 
        "cardano-cli" 
        "cardano-api" 
        "plutus-core" 
        ];
    # The foliage flake only works on this system, so we are stuck with it too
    in flake-utils.lib.eachSystem [ "x86_64-linux" ]
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

          # { ghc8107 = { foo = { X.Y.Z = <components>; ... }; ...}; ... }
          haskellPackages = 
            let
              builder = import ./builder { inherit pkgs CHaP; };
            in
            lib.recurseIntoAttrs (lib.genAttrs compilers builder);

          # A nested tree of derivations containing all the smoke test packages for all the compiler versions
          smokeTestDerivations = lib.genAttrs compilers (compiler: 
            let 
              # The latest version in the set (attrValues sorts by key). Remove the 'recurseForDerivations' here otherwise
              # we get that!
              latest = versionToValue: lib.last (lib.attrValues (builtins.removeAttrs versionToValue ["recurseForDerivations"]));
              compilerPkgs = builtins.getAttr compiler haskellPackages;
              smokeTestPkgs = lib.recurseIntoAttrs (lib.genAttrs smokeTestPackages (pkgname: latest (builtins.getAttr pkgname compilerPkgs)));
            in smokeTestPkgs);

          # The standard checks: build all the smoke test packages
          checks = flake-utils.lib.flattenTree smokeTestDerivations;

          hydraJobs = checks;
        });

  nixConfig = {
    extra-substituters = [
      "https://cache.iog.io"
      "https://foliage.cachix.org"
      "https://cache.zw3rk.com"
    ];
    extra-trusted-substituters = [
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
