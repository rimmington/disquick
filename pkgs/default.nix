{pkgs ? import (fetchTarball https://github.com/rimmington/nixpkgs/archive/934a460fd2fdd7667fa2928275aa7e0cbcab5feb.tar.gz) { inherit system; }, system ? builtins.currentSystem}:

pkgs.overridePackages (self: super: {
  mkService = self.callPackage ./mkService.nix {};
  disnix = self.callPackage ./disnix { inherit (super) disnix; };
  dysnomiaDebian = self.callPackage ./dysnomia-debian.nix {};
  disnixDebian = self.callPackage ./disnix/debian.nix {};
  disquick = self.callPackage ./disquick {};
  remoteShadow = self.callPackage ./remoteShadow.nix {};
})
