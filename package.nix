{ mkDerivation, aeson, base, bytestring, Cabal, containers
, directory, exceptions, filelock, filepath, gitrev, graph-wrapper
, hpack, hspec, HUnit, language-dot, mockery, parsec, process
, QuickCheck, safe, stdenv, temporary, time, transformers, unix
, unix-compat, with-location, yaml
}:
mkDerivation {
  pname = "tinc";
  version = "0.1.0";
  src = ./.;
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    aeson base bytestring Cabal containers directory exceptions
    filelock filepath gitrev graph-wrapper hpack language-dot parsec
    process temporary time transformers unix-compat with-location yaml
  ];
  testHaskellDepends = [
    aeson base bytestring Cabal containers directory exceptions
    filelock filepath gitrev graph-wrapper hpack hspec HUnit
    language-dot mockery parsec process QuickCheck safe temporary time
    transformers unix unix-compat with-location yaml
  ];
  homepage = "https://github.com/sol/tinc#readme";
  license = stdenv.lib.licenses.mit;
}
