{ pkgs, CHaP }:
compiler-nix-name:
let
  inherit (pkgs) lib;
  inherit (pkgs.haskell-nix) haskellLib;

  build-chap-package = package-name: package-version:
    let
      package-id = "${package-name}-${package-version}";

      # Global config needed to build CHaP packages should go here. Obviously
      # this should be kept to an absolute minimum, since that means config
      # that every downstream project needs also.
      #
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

        # Note that we do not set tests or benchmarks to True, so we won't
        # build them by default. This is the same as what happens on Hackage,
        # for example, and they can't be depended on by downstream packages
        # anyway.
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
      pkg = project.hsPkgs.${package-name};
      components = haskellLib.getAllComponents pkg;
    in pkgs.releaseTools.aggregate {
      name = package-id;
      # Note that this does *not* include the derivations from 'checks' which
      # actually run tests: CHaP will not check that your tests pass (neither
      # does Hackage).
      constituents = components;
    }; 
in build-chap-package
