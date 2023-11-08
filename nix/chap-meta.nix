{ lib, CHaP }:
let
  # type PkgName = String
  # type PkgVersion = String
  # data ChapPkgMeta = ChapPkgMeta { name :: PkgName, version :: PkgVersion }
  # type ChapMeta = [ ChapPkgMeta ]
  # type PkgVersions = Map PkgName [PkgVersion]

  # chapPackageMeta :: ChapPkgMeta
  # [ { name = "foo"; version = "X.Y.Z"; } { name = "foo"; version = "P.Q.R"; } ]
  chapPackageMeta =
    builtins.map (p: { name = p.pkg-name; version = p.pkg-version; })
      (builtins.fromJSON (builtins.readFile "${CHaP}/foliage/packages.json"));

  # chapPackageVersions :: PkgVersions
  # { foo = [ "X.Y.Z" "P.Q.R" ]; ... }
  chapPackageVersions =
    let
      # { foo = [{ name = "foo"; version = "X.Y.Z"; } { name = "foo"; version = "P.Q.R"; } ...]; ... }
      grouped = lib.groupBy (m: m.name) chapPackageMeta;
    in
    lib.mapAttrs (_name: lib.catAttrs "version") grouped;

  # chapPackageLatestVersion :: PkgVersions
  # { foo = "X.Y.Z"; ... }
  chapPackageLatestVersion =
    let latest = versions: lib.last (lib.naturalSort versions);
    in lib.mapAttrs (name: versions: latest versions) chapPackageVersions;

  # mkPackageTreeWith
  # :: (PkgName -> PkgVersion -> a)
  # -> Either PkgVersion [PkgVersion]
  # -> Map PkgName (Map PkgVersion a)
  #
  # Collect package names and versions in a hierarchical structure, calling
  # f for each package name and version.
  #
  # mkPackageTree f == { Win32-network = { "0.1.0.0" = f "Win32-network" "0.1.0.0"; ... }; ... }
  #
  mkPackageTreeWith = f:
    builtins.mapAttrs (name: versions: lib.genAttrs (lib.toList versions) (f name));

in
{
  inherit
    chapPackageMeta
    chapPackageVersions
    chapPackageLatestVersion
    mkPackageTreeWith
    ;
}
