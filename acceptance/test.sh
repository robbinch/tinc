#!/usr/bin/env bats

@test "addition using bc" {
  result="$(echo 2+2 | bc)"
  [ "$result" -eq 4 ]
}

@test "tinc can create its own nix files" {
  rm -f default.nix tinc.nix package.nix
  tinc update >&2
  [ "$?" -eq 0 ]
}

@test "tinc can bootstrap itself" {
  tinc install >&2
  [ "$?" -eq 0 ]
}
