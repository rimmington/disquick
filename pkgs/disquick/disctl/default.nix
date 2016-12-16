{pkgs ? import <nixpkgs> {}, rustPlatform ? pkgs.rustPlatform, cacert ? pkgs.cacert}:

rustPlatform.buildRustPackage {
  name = "disctl";
  src = ./.;
  depsSha256 = "14n36xfjl02791lybwzl38fq1a6616y5xcjr465bjcn4f06mglxq";
  shellHook = ''
    export SSL_CERT_FILE='${cacert}/etc/ssl/certs/ca-bundle.crt';
  '';
}
