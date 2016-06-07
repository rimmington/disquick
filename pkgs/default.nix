{pkgs ? import <nixpkgs> {}}:

pkgs.overridePackages (self: super: {
  mkService = self.callPackage ./mkService.nix {};
  disnix = self.callPackage ./disnix { inherit (super) disnix; };
  dysnomiaDebian = self.callPackage ./disnix/dysnomiaDebian.nix {};
  disnixDebian = self.callPackage ./disnix/debian.nix {};
  disquick = self.callPackage ./disquick {};
  disquickProps = self.callPackage ./disquick/manifest.nix {};
  remoteShadow = self.callPackage ./remoteShadow.nix {};
  mdocml = self.callPackage ./mdocml.nix {};
  cli2man = self.callPackage ./cli2man.nix {};
})
