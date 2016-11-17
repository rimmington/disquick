{runCommand, shadow, su}:

let
  trySbin = binary: sub: ''
    cat <<"EOF" > $out/bin/${baseNameOf binary}
    # Use local ${baseNameOf binary} if available; avoids PAM issues
    if [ -f ${binary} ]; then
      ${binary} "$@"
    else
      ${sub}/bin/${baseNameOf binary} "$@"
    fi
    EOF
  '';
in runCommand "remote-shadow" {} ''
  mkdir -p $out/bin

  ${trySbin "/usr/sbin/useradd" shadow}
  ${trySbin "/usr/sbin/groupadd" shadow}
  ${trySbin "/usr/sbin/usermod" shadow}
  ${trySbin "/bin/su" su}

  chmod +x $out/bin/*
''
