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
  echo "true" | tinc shell >&2
  nix-build -o result-bootstrap >&2
  [ "$?" -eq 0 ]
}
