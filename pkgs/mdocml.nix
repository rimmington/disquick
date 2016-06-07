{fetchurl, stdenv}:

stdenv.mkDerivation {
  name = "mdocml-1.13.3";
  src = fetchurl {
    url = http://mdocml.bsd.lv/snapshots/mdocml-1.13.3.tar.gz;
    sha256 = "23ccab4800d50bf4c327979af5d4aa1a6a2dc490789cb67c4c3ac1bd40b8cad8";
  };
  preConfigure = ''
    echo "PREFIX=$out" > configure.local
  '';
}
