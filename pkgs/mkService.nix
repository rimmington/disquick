{writeScript, buildEnv, writeTextFile, stdenv}:
{name, script, description ? "", startWithBoot ? true}@attrs:

let
  service = {
    inherit script description;
    wantedBy = if startWithBoot then [ "multi-user.target" ] else [];
  };
  scriptDrv = writeScript "${name}-now" ''
    #!${stdenv.shell}
    ${script}
  '';
  disnixDrv = buildEnv {
    name = "service-${name}";
    paths = [
      (writeTextFile { name = "${name}-disnix-process-config"; destination = "/etc/process_config"; text = ''container_process=${scriptDrv}''; })
    ];
  };
in {
  inherit attrs;
  serviceAttr = builtins.listToAttrs [ { inherit name; value = service; } ];
  script = scriptDrv;
  disnix = {
    inherit name;
    pkg = disnixDrv;
    dependsOn = {};
    type = "process";
  };
}
