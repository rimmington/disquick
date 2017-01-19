{runCommand, systemd}:

let
  trySbin = binary: sub: ''
    cat <<"EOF" > $out/bin/${baseNameOf binary}
    # Use local ${baseNameOf binary} if available; avoids version issues
    if [ -f ${binary} ]; then
      ${binary} "$@"
    else
      ${sub}/bin/${baseNameOf binary} "$@"
    fi
    EOF
  '';
in runCommand "remote-systemd" {} ''
  mkdir -p $out/bin

  ${trySbin "/bin/systemctl" systemd}
  ${trySbin "/bin/journalctl" systemd}
  ${trySbin "/bin/systemd-notify" systemd}
  ${trySbin "/usr/bin/hostnamectl" systemd}
  ${trySbin "/usr/bin/systemd-cat" systemd}

  chmod +x $out/bin/*
''
