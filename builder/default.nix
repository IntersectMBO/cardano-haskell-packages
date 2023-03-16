{ pkgs, CHaP }:
compiler-nix-name:
let
  inherit (pkgs) lib;
  inherit (pkgs.haskell-nix) haskellLib;

  # [ { name = "foo"; version = "X.Y.Z"; }, { name = "foo"; version = "P.Q.R"; } ]
  chap-package-list =
      builtins.map (p: { name = p.pkg-name; version = p.pkg-version; })
        (builtins.fromJSON (builtins.readFile "${CHaP}/foliage/packages.json"));

  # { "foo" : [ "X.Y.Z" "P.Q.R" ], ... }
  chap-package-attrs = 
    let 
      # { "foo" = [{ name = "foo"; version = "X.Y.Z"; }, { name = "foo"; version = "P.Q.R"; }]; ... }
      grouped = lib.groupBy (m: m.name) chap-package-list;
      # { "foo" : [ "X.Y.Z" "P.Q.R" ], ... }
      simplified = lib.mapAttrs (name: metas: builtins.map (m: m.version) metas) grouped;
    in simplified;

  chap-package-components = package-name: package-version:
    let
      package-id = "${package-name}-${package-version}";

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
      pkg = project.hsPkgs.${package-name};
      components = haskellLib.getAllComponents pkg;
    in lib.recurseIntoAttrs (builtins.listToAttrs (builtins.map (c: lib.nameValuePair c.pname c) components));
in
# { foo = { X.Y.Z = <components>; P.Q.R = <components>; }; ... }
lib.recurseIntoAttrs (lib.mapAttrs (name: versions: lib.recurseIntoAttrs (lib.genAttrs versions (version: chap-package-components name version))) chap-package-attrs)
