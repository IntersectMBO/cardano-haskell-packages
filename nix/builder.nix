{ pkgs, CHaP }:
compiler-nix-name:
let
  inherit (pkgs) lib;
  inherit (pkgs.haskell-nix) haskellLib;

  # Build all the derivations that we care about for a package-version.
  #
  # Note that this is not-cheap in two ways:
  # 1. Each invocation of this function will incur some IFD to run the
  # cabal solver to create a build plan.
  # 2. Since each invocation of this has its own build plan, there is
  # little chance that derivations will actually be shared between 
  # invocations.
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

        # Note that we do not set tests or benchmarks to True, so we won't
        # build them by default. This is the same as what happens on Hackage,
        # for example, and they can't be depended on by downstream packages
        # anyway.
        cabalProject = ''
          repository cardano-haskell-packages
            url: file:${CHaP}
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
      components = builtins.map
        (c: lib.attrsets.recursiveUpdate c {
          passthru = {
            addConstraint = constraint:
              let
                project' = project.appendModule { cabalProjectLocal = "constraints: ${constraint}"; };
              in
              # this is a ugly way to find the same component again
              pkgs.lib.lists.findFirst
                (c': c'.name == c.name)
                (builtins.abort "cannot find component named ${c.name} in the project anymore!")
                (haskellLib.getAllComponents project'.hsPkgs.${package-name});
          };
        })
        (haskellLib.getAllComponents pkg);

      aggregate = pkgs.releaseTools.aggregate
        {
          name = package-id;
          # Note that this does *not* include the derivations from 'checks' which
          # actually run tests: CHaP will not check that your tests pass (neither
          # does Hackage).
          constituents = components;
          # pass through the plan for debugging purposes
        };

    in
    lib.attrsets.recursiveUpdate aggregate {
      passthru = {
        inherit project;
        addConstraint = constraint: aggregate.overrideAttrs (final: prev: {
          constituents = map (c: c.passthru.addConstraint constraint) prev.constituents;
        });
      };
    };
in
build-chap-package
