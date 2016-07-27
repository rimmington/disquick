#!/bin/bash
set -eu

user="$1"

apt-get update
apt-get install -y libsqlite3-dev libgc-dev libssl-dev libbz2-dev libcurl4-openssl-dev liblzma-dev libdbi-perl libdbd-sqlite3-perl libwww-curl-perl libsodium-dev git

pushd $(mktemp -d)
    wget http://nixos.org/releases/nix/nix-1.11.2/nix-1.11.2.tar.xz
    tar xf nix-1.11.2.tar.xz
    pushd nix-1.11.2/
        ./configure --enable-gc
        make
        make install
        cp misc/systemd/nix-daemon.service misc/systemd/nix-daemon.socket /etc/systemd/system/
        systemctl enable /etc/systemd/system/nix-daemon.socket
    popd
popd

wget https://gist.githubusercontent.com/benley/e4a91e8425993e7d6668/raw/29006b251acd1bdd6dc118b06e5c4f443b98b3d7/nix-profile.sh -O /usr/local/etc/nix-profile.sh
echo 'source /usr/local/etc/nix-profile.sh' >> /etc/bash.bashrc

if [[ "$(uname -m)" =~ arm* ]]; then
    extra_caches=" http://nixos-arm.dezgeg.me/channel"
    extra_public_keys=" nixos-arm.dezgeg.me-1:xBaUKS3n17BZPKeyxL4JfbTqECsT+ysbDJz29kLFRW0=%"
else
    extra_caches=""
    extra_public_keys=""
fi
mkdir -p /usr/local/etc/nix
cat <<EOF >> /usr/local/etc/nix/nix.conf
build-users-group = nixbld
binary-caches = https://cache.nixos.org${extra_caches}
signed-binary-caches = *
binary-cache-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=${extra_public_keys}
EOF

mkStickyDir() {
    mkdir -p $1
    chmod a=rwxt $1
}

mkStickyDir /nix/var/nix/profiles/per-user
mkStickyDir /nix/var/nix/gcroots/per-user

groupadd -r nixbld
for n in $(seq 1 10); do useradd -c "Nix build user $n" \
    -d /var/empty -g nixbld -G nixbld -M -N -r -s "$(which nologin)" \
            nixbld$n; done

groupadd -r nix-users
usermod -aG nix-users $user
mkdir /etc/systemd/system/nix-daemon.socket.d
cat <<EOF > /etc/systemd/system/nix-daemon.socket.d/10-socket-group.conf
[Socket]
SocketGroup=nix-users
SocketMode=0660
EOF

echo "Done."
