{config, pkgs, system, ...}:
let
  customPkgs = import /vagrant/pkgs { inherit pkgs system; };
  rails-test = customPkgs.callPackage /vagrant/blog/service.nix { bindAddress = "192.168.100.65"; };
in
with customPkgs; {
  environment.systemPackages = [ git which disnix ];
  services.nixosManual.enable = false;

  nix.binaryCaches = [
    "https://cache.nixos.org"
  ];
  nix.binaryCachePublicKeys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
  ];

  networking.firewall.allowPing = true;
  networking.firewall.allowedTCPPorts = [
    3000
  ];

  systemd.services = rails-test.serviceAttr;
}
