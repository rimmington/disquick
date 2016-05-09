{ nixpkgs ? <nixpkgs>
, systems ? ["x86_64-linux" "armv7l-linux"]
, tanks-on-rails ? ./. }:

let
  lib = (import nixpkgs {}).lib;
in lib.genAttrs systems (system:
  let
    pkgs = import tanks-on-rails { pkgs = import nixpkgs { inherit system; }; };
  in {
    inherit (pkgs) disnixDebian disquick;
    # TODO: tests
  }
)
