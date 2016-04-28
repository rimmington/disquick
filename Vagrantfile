# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.define "nixos" do |c|
    c.vm.box = "zimbatm/nixos-15.09-x86_64"
    c.vm.hostname = "nixos"
    c.vm.network "private_network", ip: "192.168.100.65"
    c.vm.provider :virtualbox do |v|
      v.memory = 4096
      v.cpus = 1
    end
    c.vm.provision :nixos, run: 'always', path: 'configuration.nix', verbose: true, NIX_PATH: 'nixpkgs=/vagrant/nixpkgs'
  end

  config.vm.define "thebuntu" do |c|
    c.vm.box = "ubuntu/wily64"
    c.vm.hostname = "thebuntu"
    c.vm.network "private_network", ip: "192.168.100.66"
    c.vm.provider :virtualbox do |v|
      v.memory = 2048
      v.cpus = 1
    end
    c.vm.provision :shell, privileged: true, inline: <<-EOF
      apt-get install -y docker.io
    EOF
  end
end
