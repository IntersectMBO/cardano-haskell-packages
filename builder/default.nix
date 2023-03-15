{ pkgs, CHaP }:
compiler-nix-name:
let
  inherit (pkgs) lib;

  # last index state known to haskell-nix
  index-state = lib.last (builtins.attrNames (import pkgs.haskell-nix.indexStateHashesPath));

  chap-package-list =
    builtins.map (p: "${p.pkg-name}-${p.pkg-version}")
      (builtins.fromJSON (builtins.readFile "${CHaP}/foliage/packages.json"));

  build-chap-package = package-id:
    let
      package-name = (builtins.parseDrvName package-id).name;

      project = pkgs.haskell-nix.cabalProject' {
        inherit compiler-nix-name;
        inherit index-state;

        name = package-id;
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
      constituents = lib.collect lib.isDerivation {
        inherit (project.hsPkgs.pkg-a) components checks;
      };
    };

in
lib.attrsets.mapAttrs' (name: lib.attrsets.nameValuePair (builtins.replaceStrings [ "." ] [ "-" ] name)) (
  lib.attrsets.genAttrs chap-package-list build-chap-package
)
