{writeScript, buildEnv, writeTextFile, lib, stdenv, busybox, remoteShadow, coreutils, findutils, gnugrep, gnused, systemd}:
{name, script, preStartRootScript ? "", description ? "", startWithBoot ? true, user ? "root", addUser ? false, dependsOn ? [], environment ? {}, path ? []}@attrs:

# TODO: Some way to ensure dependencies are definitely included, eg. the Disnix way

assert ! (environment ? PATH);  # Use path over environment.PATH

let
  service =
    let depNames = map (s: s.attrs.name + ".service") dependsOn;
    in {
      inherit description environment path;
      wantedBy = if startWithBoot then [ "multi-user.target" ] else [];
      serviceConfig = {
        ExecStart = execStart;
      } // lib.optionalAttrs (execStartPre != "") { ExecStartPre = execStartPre; };
      wants = depNames;
      after = depNames;
    };
  execStartPre = if preStartRootScript != "" || addUser
    then writeScript "${name}-prestart" ''
      #!${stdenv.shell} -e
      ${lib.optionalString addUser ''
        if ! ${stdenv.glibc.bin}/bin/getent passwd ${user} > /dev/null; then
          ${remoteShadow}/bin/useradd --system --user-group ${user}
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
    dependsOn = builtins.listToAttrs (map (s: { name = s.attrs.name; value = s.disnix; }) dependsOn);
    pkg =
      let
        env = buildEnv {
          name = "service-${name}";
          paths = [
            (writeTextFile { name = "${name}-disnix-process-config"; destination = "/etc/process_config"; text = ''container_process="${execStart}"''; })
            (writeTextFile { name = "${name}-disnix-systemd-config"; destination = "/etc/systemd-config"; text =
              lib.optionalString (description != "") ''

              [Unit]
              Description=${description}
              '' + ''

              [Service]
              ${lib.optionalString (execStartPre != "") "ExecStartPre=${execStartPre}"}
              ${envDeclsGen "Environment="}
            ''; })
          ];
        };
      in if dependsOn == [] then env else (_dependsOn: env);
  };

  script = writeScript "${name}-now" ''
    #!${stdenv.shell} -e
    ${envDeclsGen "export "}
    ${execStartPre}
    ${execStart}
  '';
}
