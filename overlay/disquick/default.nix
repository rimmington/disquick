{lib, python35, nix, disnix, stdenv, systemd, rsync, openssh, help2man, cli2man, mdocml, ronn, disquickProps, callPackage, system, pkgs}:

let
  disctl = callPackage ./disctl {};
  version = "1.0";
  mkRonn3 = name: ''sed 's/^_/</g;s/ _script/<\&nbsp;script/g;s/\([^0-9a-zA-Z]\)_/\1</g;s/_/>/g' doc/${name}.3.md | ronn --manual="Disquick Manual" --organization="disquick ${version}" --date "1970-01-01" --roff --pipe - > $out/share/man/man3/${name}.3'';
in stdenv.mkDerivation rec {
  name = "disquick";
  src = ./.;
  buildInputs = [ python35 help2man cli2man mdocml ronn ];
  outputs = [ "out" "devdoc" ];
  installPhase = ''
    mkdir -p $out/bin $out/share/man/man{1,3} $out/libexec/disquick
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
      --replace 'PATH_TO(openssh)' ${openssh}
    substitute ./dispro.py $out/libexec/disquick/dispro \
      --replace python3 ${python35}/bin/python3
    chmod a+x $out/libexec/disquick/dispro

    ln -s ${disctl}/bin/disctl $out/bin/disctl

    export MAN=1
    cli2man $out/bin/disctl --os 'disquick ${version}' --date 1970-01-01 -I disctl.mdoc | mandoc -Tman > $out/share/man/man1/disctl.1
    help2man -S 'disquick ${version}' --name "$(ARGPARSE2MAN_DESC=1 $out/bin/disenv)" -i disenv.1.h2m $out/bin/disenv > $out/share/man/man1/disenv.1
    ${mkRonn3 "mkService"}
    ${mkRonn3 "checkServices"}
  '';
  checkPhase =
    let
      props = disquickProps { inherit serviceSet system; hostname = "localhost"; };
      serviceSet = import ./test-services.nix { inherit pkgs; inherit (props) infrastructure; };
    in ''
      [ -e ${props.manifest} ]
      [ -e ${props.distributedDerivation} ]
      ${python35}/bin/python test.py ${props.manifest}
    '';
  doCheck = true;

  meta = {
    homepage = https://github.com/rimmington/disquick;
    description = "Single-target Disnix tools";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}
