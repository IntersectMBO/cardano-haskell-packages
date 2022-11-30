{
  description = "Metadata for Cardano's Haskell package repository";

  inputs = {
    nixpkgs.follows = "haskell-nix/nixpkgs";
    foliage = {
      url = "github:andreabedini/foliage";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    haskell-nix = {
      url = "github:input-output-hk/haskell.nix";
      inputs.hackage.follows = "hackage";
    };
    hackage = { 
      url = "github:input-output-hk/hackage.nix";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, foliage, flake-utils, haskell-nix, ... }:
    let ghcVersions = [ "ghc8107" "ghc924" ];
    in flake-utils.lib.eachDefaultSystem
      (system:
        let overlays = [ haskell-nix.overlay ];
            pkgs = import nixpkgs { inherit system overlays; inherit (haskell-nix) config; };
            foliageExe = foliage.packages.${system}.default;
            nix-tools = pkgs.haskell-nix.nix-tools.ghc8107;

            package-project = { built-repo, compiler-nix-name, pkgname, version }:
              pkgs.haskell-nix.cabalProject' {
                src = ./.;
                inherit compiler-nix-name;
                inputMap = { "https://input-output-hk.github.io/cardano-haskell-packages" = built-repo; };
                # Note: tests and benchmarks are _not_ enabled, but exectuables are
                cabalProjectLocal = ''
                  extra-packages: ${pkgname}
                  constraints: ${pkgname} == ${version}
                '';
              };
            package-derivations = args@{ built-repo, compiler-nix-name,  pkgname,  version }:
              let hsPkg = (package-project args).hsPkgs.${pkgname};
              in pkgs.haskell-nix.haskellLib.getAllComponents hsPkg;

            # Job for building all components of a single package version. You have to
            # build the cabal repository yourself and pass it as an argument, since
            # building it is impure and we don't want to pin its sha here, as it will
            # change over time.
            build-pkg-job = args@{ built-repo, compiler-nix-name, pkgname, version }:
              let test-drvs = package-derivations args;
              in pkgs.releaseTools.aggregate {
                name = "${compiler-nix-name}-${pkgname}-${version}";
                constituents = test-drvs;
              };
            # Job for building a bunch of build-pkg-jobs together
            build-pkgs-job = pkg-args:
              let test-jobs = builtins.map build-pkg-job pkg-args;
              in pkgs.releaseTools.aggregate {
                name = "multi-package-job";
                constituents = test-jobs;
              };
        in {
          functions = { inherit build-pkg-job build-pkgs-job; };
          devShells.default = with pkgs; mkShellNoCC {
            name = "cardano-haskell-packages";
            buildInputs = [
              bash
              coreutils
              curlMinimal.bin
              gitMinimal
              gnutar
              foliageExe
              nix-tools
            ];
          };
        });
}
