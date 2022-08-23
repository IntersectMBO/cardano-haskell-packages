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
          packages.default = pkgs.buildEnv {
            name = "hackage-a-la-carte";
            paths = [
              pkgs.bash
              pkgs.curl
              pkgs.git
              foliage.packages.${system}.default
            ];
          };
        });
}
