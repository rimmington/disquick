{pkgs ? import <nixpkgs> { inherit system; }, system ? builtins.currentSystem}:

import pkgs.path { overlays = [ (import ./overlay) ]; inherit system; }
