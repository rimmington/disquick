{writeScript, buildEnv, writeTextFile, lib, stdenv, busybox, shadow}:
{name, script, description ? "", startWithBoot ? true, user ? "root", addUser ? false}@attrs:

let
  service = {
    inherit description;
    wantedBy = if startWithBoot then [ "multi-user.target" ] else [];
    serviceConfig.ExecStart = "${rootScript}";
  };
  rootScript =
    let
      userScript = writeScript "${name}-now" ''
        #!${stdenv.shell} -e
        ${script}
      '';
    in
      if user == "root"
        then userScript
        else writeScript "${name}-setuid" ''
          #!${stdenv.shell} -e
          ${lib.optionalString addUser ''
            if ! ${stdenv.glibc.bin}/bin/getent passwd ${user} > /dev/null; then
              ${shadow}/bin/useradd --system --user-group ${user}
            fi
          ''}
          exec ${busybox}/bin/busybox chpst -u ${user} ${userScript}
        '';
  disnixDrv = buildEnv {
    name = "service-${name}";
    paths = [
      (writeTextFile { name = "${name}-disnix-process-config"; destination = "/etc/process_config"; text = ''container_process=${rootScript}''; })
    ];
  };
in {
  inherit attrs;
  serviceAttr = builtins.listToAttrs [ { inherit name; value = service; } ];
  script = rootScript;
  disnix = {
    inherit name;
    pkg = disnixDrv;
    dependsOn = {};
    type = "process";
  };
}
