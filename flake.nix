{
  inputs = {
    nixpkgs.follows = "haskell-nix/nixpkgs";
    flake-utils.follows = "haskell-nix/flake-utils";
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

  outputs = { self, nixpkgs, flake-utils, haskell-nix, CHaP, iohk-nix, ... }:
    let 
      supportedSystems = [ "x86_64-linux" ];
      compilers = [ "ghc8107" "ghc925" ];
      chap-package-list =
        builtins.map (p: "${p.pkg-name}-${p.pkg-version}")
          (builtins.fromJSON (builtins.readFile "${CHaP}/foliage/packages.json"));
    in flake-utils.lib.eachSystem supportedSystems
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

          # last index state known to haskell-nix
          index-state = lib.last (__attrNames (import pkgs.haskell-nix.indexStateHashesPath));

          build-chap-package =
            { compiler-nix-name
            , package-id
            }:

            let
              package-name = (builtins.parseDrvName package-id).name;

              project = pkgs.haskell-nix.cabalProject' {
                inherit compiler-nix-name;
                inherit index-state;

                src = ./empty;

                inputMap = {
                  "https://input-output-hk.github.io/cardano-haskell-packages" = CHaP;
                };

                cabalProject = ''
                  repository cardano-haskell-packages
                    url: https://input-output-hk.github.io/cardano-haskell-packages
                    secure: True

                  extra-packages: ${package-id}
                '';

                modules = [{
                  packages = {
                    cardano-crypto-praos.components.library.pkgconfig = lib.mkForce [ [ pkgs.libsodium-vrf pkgs.secp256k1 ] ];
                    cardano-crypto-class.components.library.pkgconfig = lib.mkForce [ [ pkgs.libsodium-vrf pkgs.secp256k1 ] ];
                  };
                }];

              };

            in
            pkgs.releaseTools.aggregate {
              name = package-id;
              constituents = lib.collect lib.isDerivation project.hsPkgs.${package-name}.components;
            };

          all-packages = compiler-nix-name:
            lib.attrsets.mapAttrs' (name: lib.attrsets.nameValuePair (builtins.replaceStrings [ "." ] [ "-" ] name)) (
              lib.attrsets.genAttrs chap-package-list (package-id: build-chap-package {
                inherit compiler-nix-name package-id;
              })
            );

        in
        {
          hydraJobs = lib.attrsets.genAttrs compilers all-packages;
        });

  nixConfig = {
    allow-import-from-derivation = true;
    extra-substituters = [
      "https://cache.iog.io"
      "https://cache.zw3rk.com"
    ];
    extra-trusted-public-keys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "loony-tools:pr9m4BkM/5/eSTZlkQyRt57Jz7OMBxNSUiMC4FkcNfk="
    ];
  };
}
