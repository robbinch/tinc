#!/bin/sh

PROFILE=$HOME/.nix-profile/etc/profile.d/nix.sh
if [ ! -f "$PROFILE" ]; then
  echo "Setting up nix"
  export LC_ALL=C
  export LC_CTYPE=C
  export LANG=C

  mkdir -p /etc/nix
  test ! -e /etc/nix/nix.conf && echo 'build-users-group =' > /etc/nix/nix.conf
  curl -sSL https://nixos.org/nix/install | bash
else
  echo "Nix profile present, skipping nix installation"
fi

. $HOME/.nix-profile/etc/profile.d/nix.sh
nix-channel --update

install_update() {
  (nix-env -q "$1" || nix-env -Qi "$1") && nix-env -Qu "$1"
}

PKGS="bats bc"
for i in $PKGS; do
  install_update "$i"
done

nix-build -Q -o result-toolchain toolchain.nix
nix-env -i tinc -f default.nix
mkdir -p ~/.tinc
ln -sf $PWD/plugins ~/.tinc/

ls -l /nix/var/nix/gcroots/auto
