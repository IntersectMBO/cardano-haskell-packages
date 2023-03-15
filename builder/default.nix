{ pkgs, CHaP }:
compiler-nix-name:
let
  inherit (pkgs) lib;

  chap-package-list =
    builtins.filter (lib.strings.hasPrefix "plutus-core") (
      builtins.map (p: "${p.pkg-name}-${p.pkg-version}")
        (builtins.fromJSON (builtins.readFile "${CHaP}/foliage/packages.json")));

  build-chap-package = package-id:
    let
      package-name = (builtins.parseDrvName package-id).name;

      # No need to set index-state:
      # - haskell.nix will automatically use the latest known one for hackage
      # - we want the very latest state for CHaP so it includes anything from
      #   e.g. a PR being tested
      project = pkgs.haskell-nix.cabalProject' {
        inherit compiler-nix-name;

        name = package-id;
        src = ./empty;

        inputMap = {
          "https://input-output-hk.github.io/cardano-haskell-packages" = CHaP;
        };

        cabalProject = ''
          repository cardano-haskell-packages
            url: https://input-output-hk.github.io/cardano-haskell-packages
            secure: True

          -- Work around https://github.com/input-output-hk/nothunks/issues/17
          package nothunks
            flags: +vector

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
        inherit (project.hsPkgs.${package-name}) components checks;
      };
    };

in
lib.attrsets.mapAttrs' (name: lib.attrsets.nameValuePair (builtins.replaceStrings [ "." ] [ "-" ] name)) (
  lib.attrsets.genAttrs chap-package-list build-chap-package
)
