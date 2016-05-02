{pkgs ? import <nixpkgs> { inherit system; }, system ? builtins.currentSystem}:

pkgs.overridePackages (self: super: {
  mkService = self.callPackage ./mkService.nix {};
  disnix = self.callPackage ./disnix { inherit (super) disnix; };
  dysnomiaDebian = self.callPackage ./dysnomia-debian.nix {};
  disnixDebian = self.callPackage ./disnix/debian.nix {};
})
