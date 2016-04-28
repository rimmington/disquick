{callPackage, mkService}:
{bindAddress ? "localhost", port ? "3000", dataDir ? "/var/lib/rails-test"}:

let
  pkg = callPackage (import ./default.nix) { inherit dataDir; };
in mkService {
  name = "rails-test";
  script = "${pkg}/bin/rails-test -b ${bindAddress} -p ${port}";
}
