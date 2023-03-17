{ pkgs, CHaP }:
let
  inherit (pkgs) lib;
  inherit (pkgs.haskell-nix) haskellLib;


  # [ { name = "foo"; version = "X.Y.Z"; }, { name = "foo"; version = "P.Q.R"; } ]
  chap-package-list =
      builtins.map (p: { name = p.pkg-name; version = p.pkg-version; })
        (builtins.fromJSON (builtins.readFile "${CHaP}/foliage/packages.json"));

  # { "foo" : [ "X.Y.Z" "P.Q.R" ], ... }
  chap-package-versions = 
    let 
      # { "foo" = [{ name = "foo"; version = "X.Y.Z"; }, { name = "foo"; version = "P.Q.R"; }]; ... }
      grouped = lib.groupBy (m: m.name) chap-package-list;
      # { "foo" : [ "X.Y.Z" "P.Q.R" ], ... }
      simplified = lib.mapAttrs (name: metas: builtins.map (m: m.version) metas) grouped;
    in simplified;

  # { "foo" : "X.Y.Z", ... }
  chap-package-latest-versions = 
    let latest = versions: lib.last (lib.naturalSort versions);
    in lib.mapAttrs (name: versions: latest versions) chap-package-versions;

in
{
  inherit chap-package-versions chap-package-latest-versions;
}
