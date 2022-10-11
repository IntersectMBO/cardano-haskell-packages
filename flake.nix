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
          devShells.default = with pkgs; mkShell {
            name = "cardano-haskell-packages";
            buildInputs = [
              bash
              coreutils
              curl
              git
              gnutar
              foliage.packages.${system}.default
            ];
          };
        });
}
