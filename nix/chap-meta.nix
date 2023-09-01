{ lib, CHaP }:
let
  # type PkgName = String
  # type PkgVersion = String
  # data ChapPkgMeta = ChapPkgMeta { name :: PkgName, version :: PkgVersion }
  # type ChapMeta = [ ChapPkgMeta ]
  # type PkgVersions = Map PkgName [PkgVersion]

  # chap-package-meta :: ChapPkgMeta
  # [ { name = "foo"; version = "X.Y.Z"; } { name = "foo"; version = "P.Q.R"; } ]
  chap-package-meta =
    builtins.map (p: { name = p.pkg-name; version = p.pkg-version; })
      (builtins.fromJSON (builtins.readFile "${CHaP}/foliage/packages.json"));

  # chap-package-versions :: PkgVersions
  # { foo = [ "X.Y.Z" "P.Q.R" ]; ... }
  chap-package-versions =
    let
      # { foo = [{ name = "foo"; version = "X.Y.Z"; } { name = "foo"; version = "P.Q.R"; } ...]; ... }
      grouped = lib.groupBy (m: m.name) chap-package-meta;
    in
    lib.mapAttrs (_name: lib.catAttrs "version") grouped;

  # chap-package-latest-versions :: PkgVersions
  # { foo = [ "X.Y.Z" ]; ... }
  chap-package-latest-versions =
    let latest = versions: lib.last (lib.naturalSort versions);
    in lib.mapAttrs (name: versions: [ (latest versions) ]) chap-package-versions;

  # mkPackageTreeWith
  # :: (PkgName -> PkgVersion -> a)
  # -> PkgVersions
  # -> Map PkgName (Map PkgVersion a)
  #
  # Collect package names and versions in a hierarchical structure, calling
  # f for each package name and version.
  #
  # mkPackageTree f == { Win32-network = { "0.1.0.0" = f "Win32-network" "0.1.0.0"; ... }; ... }
  #
  mkPackageTreeWith = f:
    builtins.mapAttrs (name: versions: lib.genAttrs versions (f name));

in
{
  inherit
    chap-package-meta
    chap-package-versions
    chap-package-latest-versions
    mkPackageTreeWith
    ;
}
