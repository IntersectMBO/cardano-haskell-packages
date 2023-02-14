{
  inputs = {
    nixpkgs.follows = "haskell-nix/nixpkgs";
    foliage = {
      url = "github:andreabedini/foliage";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.haskell-nix.follows = "haskell-nix";
      inputs.flake-utils.follows = "flake-utils";
    };
    flake-utils.url = "github:numtide/flake-utils";
    haskell-nix = {
      url = "github:input-output-hk/haskell.nix";
      inputs.hackage.follows = "hackage-nix";
    };
    hackage-nix = {
      url = "github:input-output-hk/hackage.nix";
      flake = false;
    };
    flake-utils.follows = "haskell-nix/flake-utils";
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

          compiler-list = [ "ghc8107" "ghc925" ];

          # TODO revisit when foliage outputs metadata
          chap-package-list =
            let entries = builtins.readDir "${CHaP}/package";
            in builtins.filter (n: entries.${n} == "directory") (builtins.attrNames entries);

          build-chap-package =
            { compiler-nix-name
            , package-id
            }:

            let

              project = pkgs.haskell-nix.cabalProject' {
                inherit compiler-nix-name;
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

              flake = project.flake { };

            in
            flake.hydraJobs;

          all-packages = compiler-nix-name:
            builtins.listToAttrs (
              builtins.map
                (package-id: { name = package-id; value = build-chap-package { inherit compiler-nix-name package-id; }; })
                chap-package-list);

        in
        {
          hydraJobs = builtins.listToAttrs (
            builtins.map
              (compiler-nix-name: { name = compiler-nix-name; value = all-packages compiler-nix-name; })
              compiler-list);
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
