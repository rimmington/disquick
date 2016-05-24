{lib, python35, nix, disnix, stdenv, systemd, rsync, help2man}:

stdenv.mkDerivation rec {
  name = "disquick";
  version = "1.0";
  src = ./.;
  buildInputs = [ python35 help2man ];
  installPhase = ''
    mkdir -p $out/bin $out/share/man/man1 $out/libexec/disquick
    substitute ./disenv.py $out/bin/disenv \
      --replace libexec $out/libexec \
      --replace python3 ${python35}/bin/python3
    substitute ./disctl.py $out/bin/disctl \
      --replace libexec $out/libexec \
      --replace systemctl ${systemd}/bin/systemctl \
      --replace journalctl ${systemd}/bin/journalctl \
      --replace python3 ${python35}/bin/python3
    chmod a+x $out/bin/*

    cp ./{argparse2man,cached_property}.py $out/libexec/disquick
    substitute ./disquick.py $out/libexec/disquick/disquick.py \
      --replace "'disnix'" "'${disnix}'" \
      --replace "'rsync'" "'${rsync}/bin/rsync'"
    substitute ./dispro.py $out/libexec/disquick/dispro \
      --replace python3 ${python35}/bin/python3
    chmod a+x $out/libexec/disquick/dispro

    export ARGPARSE2MAN_MAN=1
    help2man -S 'disquick ${version}' --name "$(ARGPARSE2MAN_DESC=1 $out/bin/disenv)" -i disenv.1.h2m $out/bin/disenv > $out/share/man/man1/disenv.1
    help2man -S 'disquick ${version}' --name "$(ARGPARSE2MAN_DESC=1 $out/bin/disctl)" -i disctl.1.h2m $out/bin/disctl > $out/share/man/man1/disctl.1
  '';

  meta = {
    homepage = https://github.com/rimmington/disquick;
    description = "Single-target Disnix tools";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}
