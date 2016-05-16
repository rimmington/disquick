{pkgs ? import <nixpkgs> {}}:

pkgs.overridePackages (self: super: {
  mkService = self.callPackage ./mkService.nix {};
  disnix = self.callPackage ./disnix { inherit (super) disnix; };
  dysnomiaDebian = self.callPackage ./disnix/dysnomiaDebian.nix {};
  disnixDebian = self.callPackage ./disnix/debian.nix {};
  disquick = self.callPackage ./disquick {};
  remoteShadow = self.callPackage ./remoteShadow.nix {};
})
