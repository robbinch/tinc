#!/bin/sh

. $HOME/.nix-profile/etc/profile.d/nix.sh

bats acceptance/test.sh
