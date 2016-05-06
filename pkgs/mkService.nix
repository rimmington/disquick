{writeScript, buildEnv, writeTextFile, lib, stdenv, busybox, shadow}:
{name, script, preStartRootScript ? "", description ? "", startWithBoot ? true, user ? "root", addUser ? false}@attrs:

let
  service = {
    inherit description;
    wantedBy = if startWithBoot then [ "multi-user.target" ] else [];
    serviceConfig = {
      ExecStart = execStart;
    } // lib.optionalAttrs (execStartPre != "") { ExecStartPre = execStartPre; };
  };
  execStartPre = if preStartRootScript != "" || addUser
    then writeScript "${name}-prestart" ''
      #!${stdenv.shell} -e
      ${lib.optionalString addUser ''
        if ! ${stdenv.glibc.bin}/bin/getent passwd ${user} > /dev/null; then
          ${shadow}/bin/useradd --system --user-group ${user}
        fi
      ''}
      ${preStartRootScript}
    ''
    else "";
  execStart =
    let
      userScript = writeScript "${name}-start" ''
        #!${stdenv.shell} -e
        ${script}
      '';
    in
      if user == "root"
        then "${userScript}"
        else "${busybox}/bin/busybox chpst -u ${user} ${userScript}";
in {
  inherit attrs;

  serviceAttr = builtins.listToAttrs [ { inherit name; value = service; } ];

  disnix = {
    inherit name;
    type = "process";
    dependsOn = {};
    pkg = buildEnv {
      name = "service-${name}";
      paths = [
        (writeTextFile { name = "${name}-disnix-process-config"; destination = "/etc/process_config"; text = ''container_process=${execStart}''; })
        (writeTextFile { name = "${name}-disnix-systemd-config"; destination = "/etc/systemd-config"; text = ''

          [Unit]
          Description=${description}
        '' + lib.optionalString (execStartPre != "") ''

          [Service]
          ExecStartPre=${execStartPre}
        ''; })
      ];
    };
  };

  script = writeScript "${name}-now" ''
    #!${stdenv.shell} -e
    ${execStartPre}
    ${execStart}
  '';
}
