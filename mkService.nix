{writeScript, stdenv}:
{name, script, description ? "", startWithBoot ? true}:

let
  service = {
    inherit script description;
    wantedBy = if startWithBoot then [ "multi-user.target" ] else [];
  };
in {
  inherit service;
  serviceAttr = builtins.listToAttrs [ { inherit name; value = service; } ];
  script = writeScript "${name}-now" ''
    #!${stdenv.shell}
    ${script}
  '';
}
