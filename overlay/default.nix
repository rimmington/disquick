self: super:

{
  mkService = self.callPackage ./mkService.nix {};
  checkServices = self.callPackage ./checkServices.nix {};
  disnix = self.callPackage ./disnix { inherit (super) disnix; };
  dysnomiaDebian = self.callPackage ./disnix/dysnomiaDebian.nix {};
  disnixDebian = self.callPackage ./disnix/debian.nix {};
  disquick = self.callPackage ./disquick { disquickPkgs = ./.; };
  disquickProps = self.callPackage ./disquick/manifest.nix {};
  remoteShadow = self.callPackage ./remoteShadow.nix {};
  remoteSystemd = self.callPackage ./remoteSystemd.nix {};
  mdocml = self.callPackage ./mdocml.nix {};
  cli2man = self.callPackage ./cli2man.nix {};
  ronn = self.callPackage ./ronn {};
}
