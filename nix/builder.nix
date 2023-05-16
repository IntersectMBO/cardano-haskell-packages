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

      project = (pkgs.haskell-nix.cabalProject' {
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
      });

      aggregate = project:
        pkgs.releaseTools.aggregate
          {
            name = package-id;
            # Note that this does *not* include the derivations from 'checks' which
            # actually run tests: CHaP will not check that your tests pass (neither
            # does Hackage).
            constituents = haskellLib.getAllComponents project.hsPkgs.${package-name};
          } // {
          passthru = {
            inherit project;
            # We use cabalProjectLocal to be able to override cabalProject
            # Note: `cabalProjectLocal` ends up being prepended to the
            # existing one rather than appended. If the project has already
            # a `cabalProjectLocal` this might not give the intended result
            addCabalProject = cabalProjectLocal: aggregate (
              project.appendModule { inherit cabalProjectLocal; }
            );
            addConstraint = constraint: aggregate (
              project.appendModule { cabalProjectLocal = "constraints: ${constraint}"; }
            );
            allowNewer = allow-newer: aggregate (
              project.appendModule { cabalProjectLocal = "allow-newer: ${allow-newer}"; }
            );
          };
        };
    in
    aggregate project;
in
build-chap-package
