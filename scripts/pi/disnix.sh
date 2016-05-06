#!/bin/bash
set -eu

export NIX_PATH=nixpkgs=https://github.com/rimmington/nixpkgs/archive/934a460fd2fdd7667fa2928275aa7e0cbcab5feb.tar.gz

cloneDir="/usr/local/share/tanks-on-rails"
git clone --depth 1 https://github.com/rimmington/tanks-on-rails $cloneDir
nix-env -i -f $cloneDir/pkgs -A disnixDebian
disnixOut=$(nix-env -qa --out-path --no-name -f $cloneDir/pkgs -A disnixDebian)

groupadd disnix
usermod -aG disnix pi

cat <<"EOF" > /etc/systemd/system/dysnomia.target
[Unit]
Description=Services that are activated and deactivated by Dysnomia
After=final.target
EOF

cp $disnixOut/etc/dbus-1/system.d/disnix.conf /etc/dbus-1/system.d/
systemctl enable $disnixOut/share/disnix/disnix.service

mkdir -p /home/pi/.ssh
cat <<"EOF" >> /home/pi/.ssh/environment
NIX_REMOTE=daemon
PATH=/home/pi/.nix-profile/bin:/home/pi/.nix-profile/sbin:/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EOF
chown -R pi:pi /home/pi/.ssh

cat <<"EOF" >> /etc/ssh/sshd_config

# For NIX_REMOTE
PermitUserEnvironment yes
EOF
systemctl reload ssh

systemctl start disnix
