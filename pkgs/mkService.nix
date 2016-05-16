{writeScript, buildEnv, writeTextFile, lib, stdenv, busybox, remoteShadow, shadow, coreutils, findutils, gnugrep, gnused, systemd}:

{ name
, script
, preStartRootScript ? ""
, postStartScript ? ""
, description ? ""
, startWithBoot ? true
, user ? {}
, dependsOn ? []
, environment ? {}
, path ? []
}@attrs:

# TODO: Some way to ensure dependencies are definitely included, eg. the Disnix way
# TODO: Validate no conflicting user attributes, eg. different homes
# TODO: Networking
# TODO: RequiresMountsFor

/* DOC: User properties
If create is true, user exists and the following properties hold:
* If home is non-null, it is the $HOME of name
* If createHome is true, home exists, is owned by name:name and is the working directory for script.
  Contents not guaranteed to be owned by name. Will not move contents with home.
* If allowLogin is true, shell is not nologin and vice versa
*/

assert ! (environment ? PATH);  # Use path over environment.PATH
assert user == {} || (user.name or "root") != "root";  # Can't specify options for root
assert (! user.createHome or false) || (user.home or null) != null;  # Must specify home with createHome
assert (user.create or true) == true || (attrs.user == { create = false; name = user.name; });  # If create is false, other properties will not be applied

let
  user =
    let a = { name = "root"; home = null; allowLogin = false; } // (attrs.user or {});
    in { create = a.name != "root"; createHome = a.home != null; } // a;
  service =
    let depNames = map (s: s.attrs.name + ".service") dependsOn;
    in {
      inherit description environment path;
      wantedBy = if startWithBoot then [ "multi-user.target" ] else [];
      serviceConfig = {
        ExecStart = execStart;
      } // lib.optionalAttrs (execStartPre != "") { ExecStartPre = execStartPre; }
        // lib.optionalAttrs (execStartPost != "") { ExecStartPost = execStartPost; };
      wants = depNames;
      after = depNames;
    };
  execStartPre = if preStartRootScript != "" || user.create
    then writeScript "${name}-prestart" ''
      #!${stdenv.shell} -e
      ${lib.optionalString user.create ''
        # Setup user
        if ! ${stdenv.glibc.bin}/bin/getent passwd ${user.name} > /dev/null; then
          ${remoteShadow}/bin/useradd --system --user-group ${user.name} --home ${if user.home == null then "/var/empty" else user.home}
        fi
        ${lib.optionalString (user.home != null) "${remoteShadow}/bin/usermod --home ${user.home} ${user.name}"}
        ${lib.optionalString user.createHome ''
          ${coreutils}/bin/mkdir -m 0700 -p ${user.home}
          ${coreutils}/bin/chown ${user.name}:${user.name} ${user.home}''}
        ${if user.allowLogin
          then ''
            if [ "$(${stdenv.glibc.bin}/bin/getent passwd ${user.name} | ${coreutils}/bin/cut -d: -f7)" =~ /nologin$ ]; then
              usermod --shell "" ${user.name}
            fi
          ''
          else "${remoteShadow}/bin/usermod --shell ${shadow}/bin/nologin ${user.name}"}

        # Service prestart
      ''}
      ${preStartRootScript}''
    else "";
  runAsUser = exec: if user.name == "root" then exec else "${busybox}/bin/busybox chpst -u ${user.name} ${exec}";
  execStart =
    let
      userScript = writeScript "${name}-start" ''
        #!${stdenv.shell} -e
        ${lib.optionalString user.createHome "cd ${user.home}"}
        ${script}'';
    in runAsUser "${userScript}";
  execStartPost = lib.optionalString (postStartScript != "") (runAsUser "${writeScript "${name}-poststart" "#!${stdenv.shell} -e\n${postStartScript}"}");
  pathValue =
    let
      defaultPathPkgs = [ coreutils findutils gnugrep gnused systemd ];
      finalPath = path ++ defaultPathPkgs;
    in lib.concatStringsSep ":" (map (d: "${d}/bin") finalPath ++ map (d: "${d}/sbin") finalPath);
  envDeclsGen = prefix: (lib.mapAttrsToList (name: value: "${prefix}${name}=${value}") (environment // { PATH = pathValue; }));
in {
  inherit attrs;

  serviceAttr = builtins.listToAttrs [ { inherit name; value = service; } ];

  disnix =
    let _pkg = buildEnv {
      name = "service-${name}";
      paths = [
        (writeTextFile { name = "${name}-disnix-process-config"; destination = "/etc/process_config"; text = ''container_process="${execStart}"''; })
        (writeTextFile { name = "${name}-disnix-systemd-config"; destination = "/etc/systemd-config"; text =
          let
            section = name: items: lib.optionals (items != []) ([ "[${name}]" ] ++ items ++ [ "" ]);
            unit = section "Unit" (
              lib.optional (description != "") "Description=${description}" ++
              lib.optionals (dependsOn != []) (
                let value = lib.concatMapStringsSep " " (s: "disnix-${baseNameOf s.disnix._pkg.outPath}.service") dependsOn;
                in [ "Wants=${value}" "After=${value}" ]));
            install = section "Install" (
              lib.optional startWithBoot "WantedBy=multi-user.target");
            service = section "Service" (
              (envDeclsGen "Environment=") ++
              (lib.optional (execStartPre != "") "ExecStartPre=${execStartPre}") ++
              (lib.optional (execStartPost != "") "ExecStartPost=${execStartPost}"));
          in "\n" + lib.concatStringsSep "\n" (unit ++ install ++ service); })
      ];
    };
    in {
      inherit name _pkg;
      type = "process";
      dependsOn = builtins.listToAttrs (map (s: { name = s.attrs.name; value = s.disnix; }) dependsOn);
      pkg = if dependsOn == [] then _pkg else (_dependsOn: _pkg);
    };

  # FIXME: run execStartPost while execStart is running
  script = writeScript "${name}-now" ''
    #!${stdenv.shell} -e
    ${lib.concatStringsSep "\n" (envDeclsGen "export ")}
    ${execStartPre}
    ${execStart}
    ${execStartPost}
  '';
}
