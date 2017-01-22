{fetchurl, stdenv}:

stdenv.mkDerivation {
  name = "domoticz-3.4834";

  src = fetchurl {
    url    = http://releases.domoticz.com/releases/release/domoticz_linux_armv7l.tgz;
    sha256 = "11amcnnmpxdpfaz5d2qkcbfk54w9244hifhjfn6j3fc3wnyj3y1g";
  };

  unpackCmd = ''
    cd $out/../
    mkdir -p temp
  '';

  configPhase = ''
    echo "No config";
  '';

  dontBuild = true;

  installPhase =''
    mkdir -p $out
    tar xvfz $src -C $out
  '';
}
