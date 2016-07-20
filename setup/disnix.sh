#!/bin/bash
set -eu

user="${1:-$USER}"

export NIX_PATH=nixpkgs=https://github.com/rimmington/nixpkgs/archive/934a460fd2fdd7667fa2928275aa7e0cbcab5feb.tar.gz

cloneDir="/usr/local/share/disquick"
git clone --depth 1 https://github.com/rimmington/disquick $cloneDir
nix-env -i -f $cloneDir -A disnixDebian
disnixOut=$(nix-env -qa --out-path --no-name -f $cloneDir -A disnixDebian)

groupadd disnix
usermod -aG disnix $user

mkdir -m 2770 -p /var/lib/disenv/coordinator-profile
chown root:disnix /var/lib/disenv/coordinator-profile

cat <<"EOF" > /etc/systemd/system/dysnomia.target
[Unit]
Description=Services that are activated and deactivated by Dysnomia
After=final.target
EOF

cp $disnixOut/etc/dbus-1/system.d/disnix.conf /etc/dbus-1/system.d/
systemctl enable $disnixOut/share/disnix/disnix.service

mkdir -p /home/$user/.ssh
cat <<"EOF" >> /home/$user/.ssh/environment
NIX_REMOTE=daemon
PATH=/home/$user/.nix-profile/bin:/home/$user/.nix-profile/sbin:/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EOF
chown -R $user:$user /home/$user/.ssh

cat <<"EOF" >> /etc/ssh/sshd_config

# For NIX_REMOTE
PermitUserEnvironment yes
EOF
systemctl reload ssh

systemctl start disnix

echo "Done."
