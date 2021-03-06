{
  lib, stdenv,
  fetchFromGitHub,
  gfortran,
  cmake,
  shared ? true
}:
let
  inherit (lib) optional;
in

stdenv.mkDerivation rec {
  pname = "liblapack";
  version = "3.9.1";

  src = fetchFromGitHub {
    owner = "Reference-LAPACK";
    repo = "lapack";
    rev = "v${version}";
    sha256 = "sha256-B7eRaEY9vaLvuKkJ7d2KWanGE7OXh43O0UbXFheUWK8=";
  };

  nativeBuildInputs = [ gfortran cmake ];

  # Configure stage fails on aarch64-darwin otherwise, due to either clang 11 or gfortran 10.
  hardeningDisable = lib.optionals (stdenv.isDarwin && stdenv.isAarch64) [ "stackprotector" ];

  cmakeFlags = [
    "-DCMAKE_Fortran_FLAGS=-fPIC"
    "-DLAPACKE=ON"
    "-DCBLAS=ON"
    "-DBUILD_TESTING=ON"
  ]
  ++ optional shared "-DBUILD_SHARED_LIBS=ON";

  doCheck = true;

  # Some CBLAS related tests fail on Darwin:
  #  14 - CBLAS-xscblat2 (Failed)
  #  15 - CBLAS-xscblat3 (Failed)
  #  17 - CBLAS-xdcblat2 (Failed)
  #  18 - CBLAS-xdcblat3 (Failed)
  #  20 - CBLAS-xccblat2 (Failed)
  #  21 - CBLAS-xccblat3 (Failed)
  #  23 - CBLAS-xzcblat2 (Failed)
  #  24 - CBLAS-xzcblat3 (Failed)
  #
  # Upstream issue to track:
  # * https://github.com/Reference-LAPACK/lapack/issues/440
  ctestArgs = lib.optionalString stdenv.isDarwin "-E '^(CBLAS-(x[sdcz]cblat[23]))$'";

  checkPhase = ''
    runHook preCheck
    ctest ${ctestArgs}
    runHook postCheck
  '';

  meta = with lib; {
    description = "Linear Algebra PACKage";
    homepage = "http://www.netlib.org/lapack/";
    license = licenses.bsd3;
    platforms = platforms.all;
  };
}
