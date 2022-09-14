{
  description = "Metadata for Cardano's Haskell package repository";

  inputs = {
    foliage.url = "github:andreabedini/foliage";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, foliage, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in
        {
          packages.default = pkgs.buildEnv {
            name = "cardano-haskell-packages";
            paths = [
              pkgs.bash
              pkgs.coreutils
              pkgs.curl
              pkgs.git
              foliage.packages.${system}.default
            ];
          };
        });
}
