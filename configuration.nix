{config, pkgs, ...}:
let
  mkService = pkgs.callPackage /vagrant/pkgs/mkService.nix {};
  rails-test = pkgs.callPackage /vagrant/blog/service.nix { inherit mkService; };
in
with pkgs; {
  environment.systemPackages = [ git ];
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

  systemd.services.rails-test = (rails-test { bindAddress = "192.168.100.65"; }).service;
}
