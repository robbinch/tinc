{ nixpkgs ? import <nixpkgs> {} }:
  let
    tinc = import ./tinc.nix { inherit nixpkgs; };
    resolver = tinc.resolver;
    oldDrv = resolver.callPackage ./package.nix {};
    makeWrapper = nixpkgs.makeWrapper;
    compiler = tinc.compiler;
    ghc = compiler.ghc;
    cabal2nix = compiler.cabal2nix;
    cabal-install = compiler.cabal-install;
  in nixpkgs.lib.overrideDerivation oldDrv (oldAttrs: {
    doCheck = false;
    configureFlags = [ "--disable-tests" ];
    postInstall = ''
      source ${makeWrapper}/nix-support/setup-hook
      wrapProgram $out/bin/tinc \
        --prefix PATH : '${ghc}/bin' \
        --prefix PATH : '${cabal2nix}/bin' \
        --prefix PATH : '${cabal-install}/bin'
    '';
    src =
      let
        tarball = builtins.toPath (builtins.getEnv "PWD" + "./dist/tinc-" + oldAttrs.version + ".tar.gz");
      in if builtins.pathExists tarball then tarball else ./.;
  })
