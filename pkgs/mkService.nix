{writeScript, buildEnv, writeTextFile, lib, stdenv, busybox, shadow, coreutils, findutils, gnugrep, gnused, systemd}:
{name, script, preStartRootScript ? "", description ? "", startWithBoot ? true, user ? "root", addUser ? false, environment ? {}, path ? []}@attrs:

assert ! (environment ? PATH);  # Use path over environment.PATH

let
  service = {
    inherit description environment path;
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
  pathValue =
    let
      defaultPathPkgs = [ coreutils findutils gnugrep gnused systemd ];
      finalPath = path ++ defaultPathPkgs;
    in lib.concatStringsSep ":" (map (d: "${d}/bin") finalPath ++ map (d: "${d}/sbin") finalPath);
  envDeclsGen = prefix: lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "${prefix}${name}=${value}") (environment // { PATH = pathValue; }));
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

          [Service]
          ${lib.optionalString (execStartPre != "") "ExecStartPre=${execStartPre}"}
          ${envDeclsGen "Environment="}
        ''; })
      ];
    };
  };

  script = writeScript "${name}-now" ''
    #!${stdenv.shell} -e
    ${envDeclsGen "export "}
    ${execStartPre}
    ${execStart}
  '';
}
