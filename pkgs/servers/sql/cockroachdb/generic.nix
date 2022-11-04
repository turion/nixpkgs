{ lib, stdenv, buildGoModule, fetchurl, fetchFromGitHub, cmake, xz, which
, autoconf, ncurses6, libedit, libunwind, installShellFiles, removeReferencesTo
, yarn, git, go, procps, bazel, ccache, version, sha256, patches ? [ ] }:

buildGoModule rec {
  pname = "cockroach";
  inherit version;

  # src = fetchurl {
  #   url = "https://binaries.cockroachdb.com/cockroach-v${version}.src.tgz";
  #   inherit sha256;
  # };

  src = fetchFromGitHub {
    owner = "cockroachdb";
    repo = "cockroach";
    rev = "v${version}";
    fetchSubmodules = true;
    deepClone = true;
    inherit sha256;
  };

  vendorSha256 = null;

  NIX_CFLAGS_COMPILE = lib.optionals stdenv.cc.isGNU [
    "-Wno-error=deprecated-copy"
    "-Wno-error=redundant-move"
    "-Wno-error=pessimizing-move"
  ];

  nativeBuildInputs = [ yarn git installShellFiles cmake xz which autoconf procps bazel ];
  buildInputs = if stdenv.isDarwin then [ libunwind libedit ] else [ ncurses6 ];

  inherit patches;

  postPatch = ''
    patchShebangs .
  '';
  postUnpack = ''
    # very ugly hack :/
    mkdir -p go/src/github.com/cockroachdb
    mv source go/src/github.com/cockroachdb/cockroach
    sourceRoot=go/src/github.com/cockroachdb/cockroach
  '';
  buildPhase = ''
    echo "runHook"
    runHook preBuild
    export HOME=$TMPDIR
    echo "making buildoss"
    make buildoss
    echo "made buildoss"
    for asset in man autocomplete; do
      echo "making asset $asset"
      ./cockroachoss gen $asset
    done
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -D cockroachoss $out/bin/cockroach
    installShellCompletion cockroach.bash

    installManPage man/man1/*

    runHook postInstall
  '';

  outputs = [ "out" "man" ];

  # fails with `GOFLAGS=-trimpath`
  allowGoReference = true;
  preFixup = ''
    find $out -type f -exec ${removeReferencesTo}/bin/remove-references-to -t ${go} '{}' +
  '';

  meta = with lib; {
    homepage = "https://www.cockroachlabs.com";
    description = "A scalable, survivable, strongly-consistent SQL database";
    license = licenses.bsl11;
    platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" ];
    maintainers = with maintainers; [ rushmorem thoughtpolice turion ];
  };
}
