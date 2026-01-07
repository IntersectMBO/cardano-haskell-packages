{
  description = "Metadata for Cardano's Haskell package repository";

  inputs = {
    nixpkgs.follows = "haskell-nix/nixpkgs";
    flake-utils = { url = "github:numtide/flake-utils"; };

    foliage = {
      url = "github:input-output-hk/foliage";
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

    # Required by haskell-accumulator
    rust-accumulator = {
      url = "github:cardano-scaling/rust-accumulator";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, foliage, haskell-nix, CHaP, iohk-nix, rust-accumulator, ... }:
    let
      inherit (nixpkgs) lib;
      inherit (import ./nix/chap-meta.nix { inherit lib CHaP; }) chap-package-latest-versions chap-package-versions mkPackageTreeWith;

      smokeTestPackages = [
        "plutus-ledger-api"
        "cardano-ledger-api"
        "ouroboros-network"
        "ouroboros-consensus-cardano"
        "cardano-api"
        "cardano-node"

        # from cardano-node-emulator
        # "plutus-ledger"
        # ^ disabled as it depends on outdated versions of `cardano-api` and
        # `plutus-tx-plugin` which are not compatible with the latest
        # `plutus-ledger-api` and `plutus-tx` versions.
        # See: https://chap.intersectmbo.org/package/plutus-ledger-1.3.0.0/
        # ─ plutus-ledger-1.3.0.0
        #   └─ plutus-script-utils-1.3.0.0
        #      ├─ cardano-api-8.36.1.1 ┄┄
        #      └─ plutus-tx-plugin-1.15.0.1
        #         └─ plutus-tx-1.15.0.1 ┄┄

        # from marlowe-cardano
        "marlowe-runtime"
      ];

      # Using intersectAttrs like this is a cheap way to throw away everything
      # with keys not in smokeTestPackages
      smoke-test-package-versions =
        builtins.intersectAttrs
          (lib.genAttrs smokeTestPackages (pkg: { }))
          chap-package-latest-versions;

      # type CompilerName = String
      # type System = String
      # compilersForSystem :: System -> [CompilerName]
      compilersForSystem = system:
        # Any specific system overrides go here. Currently, there are none
        [ "ghc96" "ghc98" ];
      # compilers which we don't build for by default
      experimental-compilers = [ "ghc98" ];

      # Add exceptions to the CI here.
      #
      # Currently the following attributes are supported:
      #
      # - <compiler-nix-name>.enabled = <predicate>
      #   Excludes compiling a package with <compiler-nix-name>. By default all
      #   compilers (defined above) are included.
      #
      exceptions = {
        cardano-prelude = {
          ghc98.enabled = v : true;
        };
        ntp-client = {
          ghc98.enabled = v : builtins.compareVersions v "0.0.1.4" >= 0;
        };
        network-mux = {
          ghc98.enabled = v : builtins.compareVersions v "0.4.5.0" >= 0;
        };
        monoidal-synchronisation = {
          ghc98.enabled = v : builtins.compareVersions v "0.1.0.5" >= 0;
        };
        ouroboros-network-api = {
          ghc98.enabled = v : builtins.compareVersions v "0.6.3.0" >= 0;
        };
        ouroboros-network-mock = {
          ghc98.enabled = v : builtins.compareVersions v "0.1.1.1" >= 0;
        };
        ouroboros-network-framework = {
          ghc98.enabled = v : builtins.compareVersions v "0.11.0.0" >= 0;
        };
        ouroboros-network-protocols = {
          ghc98.enabled = v : builtins.compareVersions v "0.7.0.0" >= 0;
        };
        ouroboros-network-testing = {
          ghc98.enabled = v : builtins.compareVersions v "0.5.0.0" >= 0;
        };
        ouroboros-network = {
          ghc98.enabled = v : builtins.compareVersions v "0.11.0.0" >= 0;
        };
        cardano-ping = {
          ghc98.enabled = v : builtins.compareVersions v "0.2.0.11" >= 0;
        };
        cardano-client = {
          ghc98.enabled = v : builtins.compareVersions v "0.3.1.0" >= 0;
        };
        hasql-dynamic-syntax = {
          ghc96.enabled = v : false;
          ghc98.enabled = v : false;
        };
        marlowe-cardano = {
          ghc96.enabled = v : false;
          ghc98.enabled = v : false;
        };
        marlowe-chain-sync = {
          ghc96.enabled = v : false;
          ghc98.enabled = v : false;
        };
        marlowe-client = {
          ghc96.enabled = v : false;
          ghc98.enabled = v : false;
        };
        marlowe-protocols = {
          ghc96.enabled = v : false;
          ghc98.enabled = v : false;
        };
        marlowe-runtime = {
          ghc92.enabled = v : false;
          ghc96.enabled = v : false;
          ghc98.enabled = v : false;
        };
        marlowe-runtime-web = {
          ghc96.enabled = v : false;
          ghc98.enabled = v : false;
        };
        marlowe-test = {
          ghc96.enabled = v : false;
          ghc98.enabled = v : false;
        };
        marlowe-object = {
          ghc96.enabled = v : false;
          ghc98.enabled = v : false;
        };
        marlowe-spec-test = {
          ghc96.enabled = v : false;
          ghc98.enabled = v : false;
        };
        marlowe = {
          ghc96.enabled = v : false;
          ghc98.enabled = v : false;
        };
        marlowe-plutus = {
          ghc92.enabled = v : false;
          ghc96.enabled = v : false;
          ghc98.enabled = v : false;
        };
        plutus-core = {
          ghc98.enabled = v : true;
        };
        plutus-tx = {
          ghc98.enabled = v : true;
        };
        plutus-tx-plugin = {
          ghc92.enabled = v : false;
          ghc98.enabled = v : false;
        };
        plutus-ledger = {
          ghc92.enabled = v : builtins.compareVersions v "1.3.0.0" >= 0;
          ghc96.enabled = v : builtins.compareVersions v "1.3.0.0" >= 0;
        };
        plutus-ledger-api = {
          ghc98.enabled = v : true;
        };
        plutus-script-utils = {
          ghc92.enabled = v : builtins.compareVersions v "1.3.0.0" >= 0;
          ghc96.enabled = v : builtins.compareVersions v "1.3.0.0" >= 0;
        };
        quickcheck-contractmodel = {
          ghc96.enabled = v : false;
        };
        quickcheck-threatmodel = {
          ghc96.enabled = v : false;
        };
      };

      # Extra configurations (possibly compiler-dependent) to add to all projects.
      extraConfig = compiler:
        let addPackageKeys = x: x // { package-keys = builtins.attrNames x.packages; };
        in {
          modules = [
            (addPackageKeys {
              # Packages that depend on the plutus-tx plugin have broken haddock
              packages = {
                cardano-node-emulator.doHaddock = false;
                plutus-ledger.doHaddock = false;
                plutus-script-utils.doHaddock = false;
                plutus-scripts-bench.doHaddock = false;
              };
            })
          ];
        };

      # mkCompilerPackageTreeWith
      # :: (Compiler -> PkgName -> PkgVersions -> a)
      # -> PkgVersions
      # -> System
      # -> Map Compiler (Map PkgName (Map PkgVersion a))
      mkCompilerPackageTreeWith = f: pkg-versions: system:
        lib.genAttrs (compilersForSystem system) (compiler:
          let
            filtered-pkgs-versions =
              lib.mapAttrs
                (name: versions:
                  let predicate = lib.attrByPath
                    [ name compiler "enabled" ]
                    # the default setting depends on whether or not the compiler is
                    # experimental. Experimental compilers are disabled by default,
                    # non-experimental compilers are enabled by default
                    (v : !(builtins.elem compiler experimental-compilers))
                    exceptions;
                  in builtins.filter predicate versions)
                pkg-versions;
          in
          mkPackageTreeWith (f compiler) filtered-pkgs-versions);

      # flattenTree
      # :: Map Compiler (Map PackageName (Map PackageVersion a))
      # -> Map String a
      flattenTree =
        lib.concatMapAttrs (compiler:
          lib.concatMapAttrs (name:
            lib.concatMapAttrs (version:
              value: { "${compiler}/${name}/${version}" = value; }
            )));
    in
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            inherit (haskell-nix) config;
            overlays = [
              iohk-nix.overlays.crypto
              haskell-nix.overlay
              iohk-nix.overlays.haskell-nix-crypto

              # Required by haskell-accumulator
              (final: prev: {
                librust_accumulator = rust-accumulator.defaultPackage.${final.system};
                haskell-nix = prev.haskell-nix // {
                  extraPkgconfigMappings = prev.haskell-nix.extraPkgconfigMappings or { } // {
                    "librust_accumulator" = [ "librust_accumulator" ];
                  };
                };
              })

            ];
          };

          builder = import ./nix/builder.nix { inherit pkgs CHaP extraConfig; };

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

          haskellPackages =
            mkCompilerPackageTreeWith
              (compiler: name: version: (builder compiler name version).aggregate)
              chap-package-versions
              system;

          smokeTestPackages =
            mkCompilerPackageTreeWith
              (compiler: name: version: (builder compiler name version).aggregate)
              smoke-test-package-versions
              system;

          packages = flattenTree haskellPackages // {
            inherit update-chap-deps;

            allPackages = pkgs.releaseTools.aggregate {
              name = "all-packages";
              constituents = builtins.attrValues (flattenTree haskellPackages);
            };

            allSmokeTestPackages = pkgs.releaseTools.aggregate {
              name = "all-smoke-test-packages";
              constituents = builtins.attrValues (flattenTree smokeTestPackages);
            };
          };

          # The standard checks: build all the smoke test packages
          checks = flattenTree smokeTestPackages;

          hydraJobs =
            lib.optionalAttrs (system != "aarch64-linux")
              (mkCompilerPackageTreeWith builder smoke-test-package-versions system) //
            lib.optionalAttrs (system == "x86_64-linux")
              { inherit devShells; };
        });

  nixConfig = {
    extra-substituters = [
      "https://cache.iog.io"
      "https://foliage.cachix.org"
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
      "nixbuild.net/smart.contracts@iohk.io-1:s2PhQXWwsZo1y5IxFcx2D/i2yfvgtEnRBOZavlA8Bog="
    ];
    allow-import-from-derivation = true;
  };
}
