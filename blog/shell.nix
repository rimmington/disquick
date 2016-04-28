{nixpkgs ? import <nixpkgs> {}}:

nixpkgs.callPackage (import ./default.nix) {}
