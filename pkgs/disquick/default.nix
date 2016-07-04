{lib, python35, nix, disnix, stdenv, systemd, rsync, openssh, help2man, cli2man, mdocml, disquickPkgs, callPackage, system, pkgs}:

let
  disctl = callPackage ./disctl {};
in stdenv.mkDerivation rec {
  name = "disquick";
  version = "1.0";
  src = ./.;
  buildInputs = [ python35 help2man cli2man mdocml ];
  installPhase = ''
    mkdir -p $out/bin $out/share/man/man1 $out/libexec/disquick
    substitute ./disenv.py $out/bin/disenv \
      --replace libexec $out/libexec \
      --replace python3 ${python35}/bin/python3
    chmod a+x $out/bin/*

    cp ./{argparse2man,cached_property}.py $out/libexec/disquick
    substitute ./disquick.py $out/libexec/disquick/disquick.py \
      --replace libexec $out/libexec \
      --replace 'PATH_TO(disnix)' ${disnix} \
      --replace 'PATH_TO(nix)' ${nix.out} \
      --replace 'PATH_TO(openssh)' ${openssh} \
      --replace 'PATH_TO(rsync)' ${rsync} \
      --replace 'PATH_TO(openssh)' ${openssh} \
      --replace 'PATH_TO(disquickPkgs)' ${disquickPkgs}
    substitute ./dispro.py $out/libexec/disquick/dispro \
      --replace python3 ${python35}/bin/python3
    chmod a+x $out/libexec/disquick/dispro

    ln -s ${disctl}/bin/disctl $out/bin/disctl

    export MAN=1
    cli2man $out/bin/disctl --os 'disquick ${version}' -I disctl.mdoc | mandoc -Tman > $out/share/man/man1/disctl.1
    help2man -S 'disquick ${version}' --name "$(ARGPARSE2MAN_DESC=1 $out/bin/disenv)" -i disenv.1.h2m $out/bin/disenv > $out/share/man/man1/disenv.1
  '';
  checkPhase =
    let
      props = (import disquickPkgs { inherit system; }).disquickProps { inherit serviceSet system; hostname = "localhost"; };
      serviceSet = import ./test-services.nix { inherit pkgs; inherit (props) infrastructure; };
      manifest = props.manifest;
    in "[ -e ${manifest} ]";
  doCheck = true;

  meta = {
    homepage = https://github.com/rimmington/disquick;
    description = "Single-target Disnix tools";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}
