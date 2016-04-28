{writeScript, stdenv}:
{name, script, description ? ""}:

let
  service = {
    inherit script description;
  };
in {
  inherit service;
  serviceAttr = builtins.listToAttrs [ { inherit name; value = service; } ];
  script = writeScript "${name}-now" ''
    #!${stdenv.shell}
    ${script}
  '';
}
