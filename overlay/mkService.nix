{writeScript, buildEnv, writeTextFile, lib, stdenv, runit, remoteShadow, shadow, coreutils, findutils, gnugrep, gnused, remoteSystemd}:

# NOTE: Remember to update the man page (disquick/doc/mkService.3.ronn) upon changing

{ name
, script
, preStartRootScript ? ""
, postStartScript ? ""
, description ? ""
, startWithBoot ? true
, restartOnFailure ? true
, restartOnSuccess ? false
, user
, dependsOn ? []
, environment ? {}
, path ? []
, network ? true
, deviceAccess ? false
, runtimeDirs ? []
, runtimeDirsMode ? "0700"
, additionalWriteDirs ? []
, permitNewPrivileges ? false
, killMode ? "control-group"
, startLimitInterval ? "20s"
, exports ? {}
}@attrs:

assert ! (environment ? PATH);  # Use path over environment.PATH
assert user.name == "root" -> user == { name = "root"; };  # Can't specify options for root
assert (! user.createHome or false) || (user.home or null) != null;  # Must specify home with createHome
assert (user.create or true) == true || (attrs.user == { create = false; name = user.name; });  # If create is false, other properties will not be applied
assert killMode == "control-group" || killMode == "process";  # Strings are the best, no question
assert lib.all (p: if lib.isDerivation p then true else throw "Path must be constructed from derivations, but found a ${builtins.typeOf p} in the path of ${name}") path;
assert lib.all (n: if builtins.replaceStrings ["/"] ["_"] n == n then true else throw "Runtime directory name may not contain /, but found ${n} in the runtimeDirs of ${name}") runtimeDirs;
assert lib.all (n: if builtins.replaceStrings [" "] ["_"] n == n then true else throw "Directory paths may not contain ' ', but found ${n} in ${name}") (runtimeDirs ++ additionalWriteDirs ++ [(user.home or "")]);
assert lib.all (v: if builtins.isAttrs v && (v.type or "") == "mkService" then true else throw "Value in dependsOn does not look like a service: ${lib.showVal v}") dependsOn;

let
  user =
    let a = { name = "root"; groups = []; userGroups = []; home = null; allowLogin = false; } // (attrs.user or {});
    in { create = a.name != "root"; createHome = a.home != null; } // a;
  # Have to include /etc since we might need to alter users
  # TODO: See if the above can be fixed
  # Don't need to add /tmp with PrivateTmp
  readWriteDirectories =
    ["/etc"] ++
    map (p: "/run/${p}") runtimeDirs ++
    # Need parent dir writable to be able to create.
    # TODO: This is not actually sufficient, since the parent might not exist either.
    lib.optional (user.home != null) (dirOf user.home) ++
    additionalWriteDirs;
  # http://www.slideshare.net/warpforge/effective-service-and-resource-management-with-systemd
  commonServiceAttrs = {
    PrivateTmp = "yes";
    ProtectHome = "yes";
    CapabilityBoundingSet = "~CAP_SYS_ADMIN";  # Required for the above to stick, see systemd.exec(5)
    ReadOnlyDirectories = "/";
    ReadWriteDirectories = systemdOptionalPaths readWriteDirectories;
    InaccessibleDirectories = systemdOptionalPaths (lib.subtractLists readWriteDirectories inaccessibleDirectories);
    MountFlags = "private";  # Avoid hanging on to mounts
    SystemCallArchitectures = "native";
    RestrictAddressFamilies = "~AF_APPLETALK AF_ATMPVC AF_AX25 AF_IPX AF_NETLINK AF_PACKET AF_X25";
    KillMode = killMode;
    Restart =
      if restartOnSuccess && restartOnFailure
        then "always"
      else if restartOnFailure
        then "on-failure"
      else if restartOnSuccess
        then "on-success"
      else   "no";
    StartLimitBurst = "5";
    StartLimitInterval = startLimitInterval;  # Here instead of in [Unit] for backwards compat
  } // lib.optionalAttrs (execStartPre != "") { ExecStartPre = execStartPre; }
    // lib.optionalAttrs (execStartPost != "") { ExecStartPost = execStartPost; }
    // lib.optionalAttrs (!network) { PrivateNetwork = "yes"; }
    // lib.optionalAttrs (!deviceAccess) { PrivateDevices = "yes"; }
    // lib.optionalAttrs (!permitNewPrivileges) { NoNewPrivileges = "yes"; }
    // lib.optionalAttrs (runtimeDirs != []) {
          RuntimeDirectory = systemdRequiredPaths runtimeDirs;
          RuntimeDirectoryMode = runtimeDirsMode;
       };
  commonUnitAttrs = {
    RequiresMountsFor = systemdRequiredPaths readWriteDirectories;
  };
  execStartPre = optionalScript "${name}-prestart" (lib.concatStrings [
    (lib.optionalString user.create ''
      # Setup user
      if ! ${stdenv.glibc.bin}/bin/getent passwd ${user.name} > /dev/null; then
        ${remoteShadow}/bin/useradd --system --user-group ${user.name} --home ${if user.home == null then "/var/empty" else user.home}
      fi
      ${lib.concatMapStrings (group: "${remoteShadow}/bin/groupadd -f ${group}\n") user.userGroups}
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
    '')
    (lib.concatMapStrings (p: ''
      chown ${user.name}:nogroup '/run/${p}'
    '') runtimeDirs)
    (lib.optionalString (preStartRootScript != "") "\n# Service prestart\n${preStartRootScript}")
  ]);
  execStart =
    let
      userScript = writeScript "${name}-start" ''
        #!${stdenv.shell} -e
        ${lib.optionalString user.createHome "cd ${user.home}"}
        ${script}'';
    in runAsUser "${userScript}";
  execStartPost = lib.optionalString (postStartScript != "") (runAsUser "${writeScript "${name}-poststart" "#!${stdenv.shell} -e\n${postStartScript}"}");
  optionalScript = name: content: lib.optionalString (content != "") (writeScript name "#!${stdenv.shell} -e\n${content}");
  runAsUser = exec:
    if user.name == "root"
      then exec
      else
        let
          allGroups = user.groups ++ user.userGroups;
          suf = lib.concatMapStrings (g: ":${g}") allGroups;
        in "${chpst} -u ${user.name}${suf} ${exec}";
  finalPath =
    let defaultPathPkgs = [ coreutils findutils gnugrep gnused remoteSystemd ];
    in  path ++ defaultPathPkgs;
  envDeclsGen =
    let pathValue = lib.concatStringsSep ":" (map (d: "${d}/bin") finalPath ++ map (d: "${d}/sbin") finalPath);
    in  prefix: (lib.mapAttrsToList (name: value: "${prefix}${name}=${value}") (environment // { PATH = pathValue; }));
  systemdOptionalPaths = lib.concatMapStringsSep " " (p: ''-${p}'');
  systemdRequiredPaths = lib.concatMapStringsSep " " (p: ''${p}'');
  # http://systemd-devel.freedesktop.narkive.com/BDN0gv3G/use-of-capabilities-in-default-service-files
  inaccessibleDirectories = [
    # Additional directories are made inaccessible via ProtectHome
    "/boot"
    "/media"
    "/etc/dbus-1"
    "/etc/modprobe.d"
    "/etc/modules-load.d"
    "/etc/postfix"
    "/etc/ssh"
    "/etc/sysctl.d"
    "/run/console"
    "/run/dbus"
    "/run/lock"
    "/run/mount"
    "/run/systemd/generator"
    "/run/systemd/system"
    "/run/systemd/users"
    "/run/udev"
    "/sbin"
    "/usr/lib/apt"
    "/usr/lib/dpkg"
    "/usr/lib/grub"
    "/usr/lib/kernel"
    "/usr/lib/modprobe.d"
    "/usr/lib/modules"
    "/usr/lib/modules-load.d"
    "/usr/lib/rpm"
    "/usr/lib/sysctl.d"
    "/usr/lib/udev"
    "/usr/local"
    "/var/backups"
    "/var/cron"
    "/var/db"
    "/var/lib/apt"
    "/var/lib/dbus"
    "/var/lib/dnf"
    "/var/lib/dpkg"
    "/var/lib/rpm"
    "/var/lib/systemd"
    "/var/lib/yum"
    "/var/mail"
    "/var/opt"
    "/var/spool"
    "/var/tmp"
  ];
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
        inherit description environment;
        path = lib.mkForce finalPath;
        wantedBy = if startWithBoot then [ "multi-user.target" ] else [];
        serviceConfig = { ExecStart = execStart; } // commonServiceAttrs;
        unitConfig = commonUnitAttrs;
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
              in [ "Wants=${value}" "After=${value}" ]) ++
            lib.optional network "After=network.target" ++
            (lib.mapAttrsToList (name: value: "${name}=${value}") commonUnitAttrs));
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

  type = "mkService";
}
