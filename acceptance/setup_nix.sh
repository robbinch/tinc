#!/bin/sh

PROFILE=$HOME/.nix-profile/etc/profile.d/nix.sh
REBUILD_NIX=0

setup_etc_nix () {
  NIX_CONF="/etc/nix/nix.conf"
  test ! -e "$NIX_CONF" && (
    echo "Creating $NIX_CONF"
    echo 'build-users-group =' >> "$NIX_CONF"
    echo 'build-max-jobs = 4' >> "$NIX_CONF"
  )
}

if [ "$REBUILD_NIX" != 1 ] && [ -d /nix/var/nix/profiles ] && [ ! -f "$PROFILE" ]; then
  echo "/nix/var/nix/profiles present, not installing nix"
  ln -s /nix/var/nix/profiles/default $HOME/.nix-profile
  mkdir -p $HOME/.nix-defexpr
  ln -s /nix/var/nix/profiles/per-user/root/channels $HOME/.nix-defexpr/
else
  echo "Setting up nix"
  export LC_ALL=C
  export LC_CTYPE=C
  export LANG=C

  setup_etc_nix
  curl -sSL https://nixos.org/nix/install | bash
  REBUILD_NIX=1
fi

setup_etc_nix
. $HOME/.nix-profile/etc/profile.d/nix.sh

restore_db () {
  REGINFO=$HOME/rootfs.meta/reginfo
  if [ "$REBUILD_NIX" != 1 ] && [ -f "$REGINFO" ]; then
    echo "Restoring nix db"
    nix-store --load-db < "$REGINFO"
  fi
}

update_channel () {
  nix-channel --list | grep -q "^nixpkgs" || nix-channel --add https://nixos.org/channels/nixpkgs/unstable
  nix-channel --update
}

install_update () {
  echo "Installing/updating $1"
  (nix-env -q "$1" || nix-env -Qi "$1") && nix-env -Qu "$1"
}

restore_db
update_channel
PKGS="bats bc cabal-install"
for i in $PKGS; do
  install_update "$i"
done

create_epoch_tar () {
  echo "Creating epoch-timestamped source tarball"
  (
    cabal sdist
    cd dist
    TARBALL=$(ls *.tar.gz)
    tar -xf "$TARBALL"
    rm "$TARBALL"
    find tinc-* -exec touch -d "1970-01-01 00:00:00 UTC" {} \;
    tar -cf "$TARBALL" tinc-*
  )
}

create_epoch_tar

echo "Building toolchain for tinc"
nix-build -Q -o result-toolchain toolchain.nix

echo "Installing tinc"
nix-env -i tinc -f default.nix
mkdir -p ~/.tinc
ln -sf $PWD/plugins ~/.tinc/
