{ stdenv, mkDerivation, Agda, fetchFromGitHub }:

mkDerivation (rec {
  version = "1.5.0";
  pname = "iowa-stdlib";

  src = fetchFromGitHub {
    owner = "cedille";
    repo  = "ial";
    rev = "v${version}";
    sha256 = "0dlis6v6nzbscf713cmwlx8h9n2gxghci8y21qak3hp18gkxdp0g";
  };

  libraryFile = "";
  libraryName = "IAL-1.3";

  buildPhase = ''
    patchShebangs find-deps.sh
    make
  '';

  meta = {
    homepage = "https://svn.divms.uiowa.edu/repos/clc/projects/agda/lib/";
    description = "Agda standard library developed at Iowa";
    license = stdenv.lib.licenses.free;
    platforms = stdenv.lib.platforms.unix;
    maintainers = with stdenv.lib.maintainers; [ alexarice ];
  };
})
