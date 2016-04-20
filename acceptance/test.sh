#!/usr/bin/env bats

@test "addition using bc" {
  result="$(echo 2+2 | bc)"
  [ "$result" -eq 4 ]
}

@test "tinc can create its own nix files" {
  run tinc update
  [ "$status" -eq 0 ]
}

@test "tinc can bootstrap itself" {
  run tinc install
  [ "$status" -eq 0 ]
}
