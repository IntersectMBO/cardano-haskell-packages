{ pkgs, CHaP }:
let
  inherit (pkgs) lib;
  inherit (pkgs.haskell-nix) haskellLib;

  # type PkgName = String
  # type PkgVersion = String
  # data ChapPkgMeta = ChapPkgMeta { name :: PkgName, version :: PkgVersion }
  # type ChapMeta = [ ChapPkgMeta ]
  # type PkgVersions = Map PkgName [PkgVersion] 

  # chap-package-meta :: ChapPkgMeta
  # [ { name = "foo"; version = "X.Y.Z"; }, { name = "foo"; version = "P.Q.R"; } ]
  chap-package-meta =
      builtins.map (p: { name = p.pkg-name; version = p.pkg-version; })
        (builtins.fromJSON (builtins.readFile "${CHaP}/foliage/packages.json"));

  # chap-package-versions :: ChapPkgMeta -> PkgVersions
  # { "foo" : [ "X.Y.Z" "P.Q.R" ], ... }
  chap-package-versions = pkg-list:
    let 
      # { "foo" = [{ name = "foo"; version = "X.Y.Z"; }, { name = "foo"; version = "P.Q.R"; }]; ... }
      grouped = lib.groupBy (m: m.name) pkg-list;
      # { "foo" : [ "X.Y.Z" "P.Q.R" ], ... }
      simplified = lib.mapAttrs (name: metas: builtins.map (m: m.version) metas) grouped;
    in simplified;

  # chap-package-latest-versions :: ChapPkgMeta -> PkgVersions
  # { "foo" : ["X.Y.Z"], ... }
  chap-package-latest-versions = pkg-list:
    let latest = versions: lib.last (lib.naturalSort versions);
    in lib.mapAttrs (name: versions: [(latest versions)]) (chap-package-versions pkg-list);

in
{
  inherit chap-package-meta chap-package-versions chap-package-latest-versions;
}
