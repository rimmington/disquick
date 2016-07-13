{writeScript, buildEnv, writeTextFile, lib, stdenv, runit, remoteShadow, shadow, coreutils, findutils, gnugrep, gnused, systemd}:

# NOTE: Remember to update the man page (disquick/doc/mkService.3.ronn) upon changing

{ name
, script
, preStartRootScript ? ""
, postStartScript ? ""
, description ? ""
, startWithBoot ? true
, restartOnFailure ? true
, restartOnSuccess ? false
, user ? {}
, dependsOn ? []
, environment ? {}
, path ? []
, network ? true
, killMode ? "control-group"
, exports ? {}
}@attrs:

# TODO: RequiresMountsFor
# TODO: Good security defaults, see systemd.service(5) and links

assert ! (environment ? PATH);  # Use path over environment.PATH
assert user == {} || (user.name or "root") != "root";  # Can't specify options for root
assert (! user.createHome or false) || (user.home or null) != null;  # Must specify home with createHome
assert (user.create or true) == true || (attrs.user == { create = false; name = user.name; });  # If create is false, other properties will not be applied
assert killMode == "control-group" || killMode == "process";  # Strings are the best, no question
assert lib.all (p: if lib.isDerivation p then true else throw "Path must be constructed from derivations, but found a ${builtins.typeOf p} in the path of ${name}") path;

let
  user =
    let a = { name = "root"; groups = []; home = null; allowLogin = false; } // (attrs.user or {});
    in { create = a.name != "root"; createHome = a.home != null; } // a;
  commonServiceAttrs = {
    KillMode = killMode;
    Restart =
      if restartOnSuccess && restartOnFailure
        then "always"
      else if restartOnFailure
        then "on-failure"
      else if restartOnSuccess
        then "on-success"
      else   "no";
  } // lib.optionalAttrs (execStartPre != "") { ExecStartPre = execStartPre; }
    // lib.optionalAttrs (execStartPost != "") { ExecStartPost = execStartPost; }
    // lib.optionalAttrs (!network) { PrivateNetwork = true; };
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
            if [[ "$(${stdenv.glibc.bin}/bin/getent passwd ${user.name} | ${coreutils}/bin/cut -d: -f7)" =~ /nologin$ ]]; then
              ${remoteShadow}/bin/usermod --shell "" ${user.name}
            fi
          ''
          else "${remoteShadow}/bin/usermod --shell ${shadow}/bin/nologin ${user.name}"}

        # Service prestart
      ''}
      ${preStartRootScript}''
    else "";
  execStart =
    let
      userScript = writeScript "${name}-start" ''
        #!${stdenv.shell} -e
        ${lib.optionalString user.createHome "cd ${user.home}"}
        ${script}'';
    in runAsUser "${userScript}";
  execStartPost = lib.optionalString (postStartScript != "") (runAsUser "${writeScript "${name}-poststart" "#!${stdenv.shell} -e\n${postStartScript}"}");
  runAsUser = exec:
    if user.name == "root"
      then exec
      else
        let suf = lib.optionalString (user.groups != []) ":${lib.concatStringsSep ":" user.groups}";
        in "${chpst} -u ${user.name}${suf} ${exec}";
  pathValue =
    let
      defaultPathPkgs = [ coreutils findutils gnugrep gnused systemd ];
      finalPath = path ++ defaultPathPkgs;
    in lib.concatStringsSep ":" (map (d: "${d}/bin") finalPath ++ map (d: "${d}/sbin") finalPath);
  envDeclsGen = prefix: (lib.mapAttrsToList (name: value: "${prefix}${name}=${value}") (environment // { PATH = pathValue; }));
  chpst = lib.overrideDerivation runit (o: {
    name = "runit-${o.version}-chpst";
    # https://github.com/NixOS/nixpkgs/blob/7a37ac15b3fdca4dfa5c16fcc2a4de1294f5dc87/pkgs/tools/system/runit/default.nix
    phases = [ "unpackPhase" "patchPhase" "buildPhase" "checkPhase" "installPhase" "fixupPhase" ];
    postPatch = ''
      cd ${o.name}
      sed -i 's,-static,,g' src/Makefile
    '';
    buildPhase = ''
      make -C 'src'
    '';
    installPhase = "mv src/chpst $out";
  });
in {
  inherit attrs exports;

  serviceAttr = {
    "${name}" =
      let depNames = map (s: s.attrs.name + ".service") dependsOn;
      in {
        inherit description environment path;
        wantedBy = if startWithBoot then [ "multi-user.target" ] else [];
        serviceConfig = { ExecStart = execStart; } // commonServiceAttrs;
        wants = depNames;
        after = depNames ++ lib.optional network "network.target";
      };
  };

  disnix =
    let _pkg = stdenv.mkDerivation {
      name = "service-${name}";
      passAsFile = [ "processConfig" "systemdConfig" ];
      buildCommand = ''
        mkdir -p $out/etc
        cp $processConfigPath $out/etc/process_config
        cp $systemdConfigPath $out/etc/systemd-config
      '';

      processConfig = ''container_process="${execStart}"'';
      systemdConfig =
        let
          section = name: items: lib.optionals (items != []) ([ "[${name}]" ] ++ items ++ [ "" ]);
          unit = section "Unit" (
            lib.optional (description != "") "Description=${description}" ++
            lib.optionals (dependsOn != []) (
              let value = lib.concatMapStringsSep " " (s: "disnix-${baseNameOf s.disnix._pkg.outPath}.service") dependsOn;
              in [ "Wants=${value}" "After=${value}" ])) ++
            lib.optional network "After=network.target";
          install = section "Install" (
            lib.optional startWithBoot "WantedBy=multi-user.target");
          service = section "Service" (
            (envDeclsGen "Environment=") ++
            (lib.mapAttrsToList (name: value: "${name}=${value}") commonServiceAttrs));
        in "\n" + lib.concatStringsSep "\n" (unit ++ install ++ service);
    };
    in {
      inherit name _pkg;
      type = "process";
      dependsOn = builtins.listToAttrs (map (s: { name = s.attrs.name; value = s.disnix; }) dependsOn);
      pkg = if dependsOn == [] then _pkg else (_dependsOn: _pkg);
    };

  # FIXME: run execStartPost while execStart is running
  # TODO: Clean environment?
  script = writeScript "${name}-now" ''
    #!${stdenv.shell} -e
    ${lib.concatStringsSep "\n" (envDeclsGen "export ")}
    ${execStartPre}
    ${execStart}
    ${execStartPost}
  '';
}
