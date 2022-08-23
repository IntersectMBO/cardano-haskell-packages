{
  inputs = {
    foliage.url = "github:andreabedini/foliage";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, foliage, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in
        {
          apps.foliage = {
              type = "app";
              program = "${foliage.packages.${system}.default}/bin/foliage";
          };
          packages.default = pkgs.buildEnv {
            name = "hackage-a-la-carte";
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
