{ nixpkgs ? <nixpkgs>
, systems ? ["x86_64-linux" "armv7l-linux"]
, tanks-on-rails ? ./. }:

let
  lib = (import nixpkgs {}).lib;
in lib.genAttrs systems (system:
  let
    pkgs = import "${tanks-on-rails}/pkgs" { inherit system; pkgs = import nixpkgs { inherit system; }; };
    service = pkgs.callPackage "${tanks-on-rails}/blog/service.nix" {};
  in {
    inherit (pkgs) disnixDebian disquick;
    rails-test = { inherit (service) script; };
  }
)
