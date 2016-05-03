{python3, nix, disnix, stdenv}:

stdenv.mkDerivation {
  name = "disquick";
  src = ./.;
  buildInputs = [ python3 ];
  installPhase = ''
    mkdir -p $out/bin
    substitute ./disquick.py $out/bin/disquick \
      --replace disnix-env ${disnix}/bin/disnix-env \
      --replace python3 ${python3}/bin/python3
    chmod a+x $out/bin/disquick
  '';
}
