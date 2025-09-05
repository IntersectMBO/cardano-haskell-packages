{ pkgs, CHaP, extraConfig }:
# Build all the derivations that we care about for a package-version.
#
# Note that this is not-cheap in two ways:
# 1. Each invocation of this function will incur some IFD to run the
# cabal solver to create a build plan.
# 2. Since each invocation of this has its own build plan, there is
# little chance that derivations will actually be shared between
# invocations.
compiler-nix-name: package-name: package-version:
let
  inherit (pkgs.haskell-nix) haskellLib;
  package-id = "${package-name}-${package-version}";

  # Global config needed to build CHaP packages should go here. Obviously
  # this should be kept to an absolute minimum, since that means config
  # that every downstream project needs also.
  #
  # No need to set index-state:
  # - haskell.nix will automatically use the latest known one for hackage
  # - we want the very latest state for CHaP so it includes anything from
  #   e.g. a PR being tested
  project = pkgs.haskell-nix.cabalProject' [
    {
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
        constraints: ghc source
        allow-newer: ghc:Cabal
      '';
      configureArgs = "--allow-boot-library-installs";

      modules = [{
        postHaddock = ''
          mkdir $doc/nix-support
          echo "doc haddock $docdir/html" >> $doc/nix-support/hydra-build-products
        '';
      }];
    }
    (extraConfig compiler-nix-name)
  ];

  # Expose selected package derivations
  #
  # The wrapper also provides shortcuts to quickly manipulate the cabal project.
  #
  # - addCabalProject adds arbitrary configuration to the project's cabalProjectLocal
  # - addConstraint uses addCabalProject to add a "constraints: " stanza
  # - allowNewer uses addCabalProject to add a "allow-newer: " stanza
  #
  # Note 1: We use cabalProjectLocal to be able to override cabalProject
  # Note 2: `cabalProjectLocal` ends up being prepended to the existing one
  # rather than appended. I think this is haskell.nix bug. If the project
  # has already a `cabalProjectLocal` this might not give the intended
  # result.
  mkJob = project:
    let
      # package components
      components =
        haskellLib.mkFlakePackages
          { ${package-name} = project.hsPkgs.${package-name}; };

      # package components documentation
      docs = pkgs.lib.concatMapAttrs
        (cn: c: pkgs.lib.optionalAttrs (c ? doc) {
          "${cn}:haddock" = c.doc;
        })
        components;
    in
    components
    // docs
    // {
      aggregate = (pkgs.releaseTools.aggregate {
        name = package-id;
        constituents = builtins.attrValues components ++ builtins.attrValues docs;
      }) // {
        passthru = {
          # pass through the project for debugging purposes
          inherit project;
          # Shortcuts to manipulate the project, see above
          addCabalProject = cabalProjectLocal: mkJob (
            project.appendModule { inherit cabalProjectLocal; }
          );
          addConstraint = constraint: mkJob (
            project.appendModule { cabalProjectLocal = "constraints: ${constraint}"; }
          );
          allowNewer = allow-newer: mkJob (
            project.appendModule { cabalProjectLocal = "allow-newer: ${allow-newer}"; }
          );
        };
      };
    }
  ;
in
mkJob project
