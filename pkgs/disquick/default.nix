{python3, nix, disnix, stdenv, systemd}:

stdenv.mkDerivation {
  name = "disquick";
  src = ./.;
  buildInputs = [ python3 ];
  installPhase = ''
    mkdir -p $out/bin
    substitute ./disenv.py $out/bin/disenv \
      --replace "'disnix'" "'${disnix}'"
    substitute ./disctl.py $out/bin/disctl \
      --replace systemctl ${systemd}/bin/systemctl
    chmod a+x $out/bin/*
  '';
}
