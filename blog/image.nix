let
  nixpkgs = import <nixpkgs> {};
  buildAci = import ../../pkgs/lib/buildAci.nix nixpkgs;
  pkg = nixpkgs.callPackage (import ./default.nix) {};
in buildAci {
  name = "rails-test";
  version = "dev";
  contents = [ pkg ];
  extraManifest.app = {
    user = "0";
    group = "0";
    exec = [ "${pkg}/bin/rails-test" ];
    workingDirectory = "${pkg}";
    ports = [
      { name = "http"; port = 3000; protocol = "tcp"; }
    ];
  };
}
