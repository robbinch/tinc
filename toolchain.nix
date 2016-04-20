# install with:
# nix-build -j4 -o result-toolchain toolchain.nix
{ nixpkgs ? import <nixpkgs> {} }:

with nixpkgs;
let
  oldDefault = import ./default.nix { inherit nixpkgs; };
  oldShell = import ./shell.nix { inherit nixpkgs; };
in {
  default = lib.overrideDerivation oldDefault (oldAttrs: {
    phases = [ "installPhase" ];
    name = "${oldAttrs.name}-default-toolchain";
    installPhase = ''
      mkdir -p $out

      echo "$PATH " >> $out/paths
      echo "$LOCALE_ARCHIVE " >> $out/paths
      echo "$setupCompilerEnvironmentPhase " >> $out/paths
      echo "$stdenv " >> $out/paths
      echo "$nativeBuildInputs " >> $out/paths
    '';
  });

  shell = lib.overrideDerivation oldShell (oldAttrs: {
    phases = [ "installPhase" ];
    name = "${oldAttrs.name}-shell-toolchain";
    installPhase = ''
      mkdir -p $out

      echo "$LOCALE_ARCHIVE " >> $out/paths
      echo "$stdenv " >> $out/paths
      echo "$nativeBuildInputs " >> $out/paths
    '';
  });
}
