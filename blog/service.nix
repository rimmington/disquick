{callPackage, mkService, bindAddress ? "localhost", port ? "3000", dataDir ? "/var/lib/rails-test"}:

let
  pkg = callPackage (import ./default.nix) { inherit dataDir; };
in mkService {
  name = "rails-test";
  description = "Ruby on Rails test service";
  script = "exec ${pkg}/bin/rails-test -b ${bindAddress} -p ${port}";
  preStartRootScript = ''echo "WOO $WOO" > /root/rails-test'';
  path = [ pkg ];
  environment.WOO = "HOO";
}
