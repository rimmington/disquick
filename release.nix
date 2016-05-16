{ nixpkgs ? <nixpkgs>
, systems ? ["x86_64-linux" "armv7l-linux"]
, disquick ? ./. }:

let
  lib = (import nixpkgs {}).lib;
in lib.genAttrs systems (system:
  let
    pkgs = import disquick { pkgs = import nixpkgs { inherit system; }; };
  in {
    inherit (pkgs) disnixDebian disquick;
    # TODO: tests
  }
)
