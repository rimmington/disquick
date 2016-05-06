{pkgs ? import <base-nixpkgs> { inherit system; }, system ? builtins.currentSystem}:

import ./pkgs { inherit pkgs system; }
