mkService(3) - realise a service description in a number of formats
===================================================================

## SYNOPSIS

**pkgs.mkService {** name, script, user, ... **} -> {** attrs, serviceAttr, disnix, script, exports **}**

## DESCRIPTION

`mkService` transforms a description of a system service into descriptions for NixOS and Disnix as well as a shell script.

The service is executed in a clean, restricted environment via systemd:

* Only environment variables explicitly specified in the _environment_ argument and the systemd-generated variables (see `systemd.exec`(5)) are available to the service.
* The `PATH` environment variable includes the following utilities: systemd, Coreutils, findutils, GNU grep, GNU sed. You can add more by adding Nix packages to the _path_ argument.
* The filesystem is mostly read-only, irrespective of filesystem permissions. The directories specified by _user.home_ and _runtimeDirs_ are writable by default; _additionalWriteDirs_ are writable subject to filesystem permissions.
* A number of directories are inaccessible, including the entirety of `/home`, `/root`, `/media` and `/boot`; this can be carefully overridden via _additionalWriteDirs_. See the `mkService` source for a full list.
* The service has a private `/tmp` directory, accessible only by itself.
* Access to physical devices in `/dev` is not permitted by default (see _deviceAccess_). Pseudo-devices like `/dev/null` and `/dev/random` are still available.

## OPTIONS

### Descriptive arguments

* _name_:
  Unique service name of the form "my-service-name".

* _description_:
  Optional very short description, as in "My Service replica server".

* _exports_:
  A passthrough attrset useful for providing additional information to dependents.

### Script arguments

Each script argument is a Bash script. _preStartRootScript_ is run as root, and should do any environment or filesystem setup that requires root privileges. _script_ should do any non-root setup and end with `exec my-executable --my-flags`. If the executable needs to take steps before the service can be considered active, do any waiting in _postStartScript_.

### Ordering arguments

* _startWithBoot_:
  Whether to start the service on boot. Default `true`.

* _dependsOn_:
  A list of other services this service must be started after. Values of the list are other `mkService` return values. Default `[]` (empty).

* _restartOnFailure_:
  Whether to restart the service if it fails. Restarts are throttled, so this won't restart endlessly. See `systemd.service`(5) for more details on what "failure" means. Default `true`.

* _restartOnSuccess_:
  Whether to restart the service if it terminates cleanly. Default `false`.

* _startLimitInterval_:
  Configures restart throttling. If a service restarts more than 5 times within this time limit, it will no longer be restarted automatically. Format is something like "30s" or "2min 5s", see `systemd.time`(7). Default `"20s"`.

* _killMode_:
  See `systemd.service`(5). Accepts "control-group" or "process". Default "control-group".

### Environment arguments

* _environment_:
  An attrset of environment variables available to each of the service scripts. Note the [SECURITY][] section below.

* _path_:
  A list of packages. The `bin` directory of each package is included in the `PATH` environment variable.

* _network_:
  Whether the service uses the network. If `false`, the service runs in its own network namespace with a single private loopback interface. Default `true`.

* _deviceAccess_:
  Whether the service needs access to physical (non-pseudo-) devices. Default `false`.

* _runtimeDirs_:
  A list of directory names to be created under `/run` before the service is launched and removed after it ends. The directories will have the access mode specified in _runtimeDirsMode_, and will be owned by _user.name_:`nogroup`. Names must not include a "/". Default `[]`.

* _runtimeDirsMode_:
  The permissions/mode bits of directories created through _runtimeDirs_, as a string in a format accepted by `mkdir`(1). Default `"0700"`.

* _additionalWriteDirs_:
  Additional directories the service needs write access to. Note that this may make accessible directories typically made inaccessible for security hardening. The directories will not be automatically created or altered in any way; this argument only permits the possibility of write access. Default `[]`.

* _permitNewPrivileges_:
  If `false`, ensures that the service process and all its children can never gain new privileges and prohibits UID changes of any kind. This inhibits the use of setuid executables like `ping`. Default `false`.

### user argument

The _user_ argument is an attrset of user-related parameters.

* _name_:
  The user to run as. If "root", no other user parameters can be set. Mandatory.

* _create_:
  Whether to create the user before _preStartRootScript_. Must be `true` in order to set any other non-_name_ parameters. Default `true`.

* _groups_:
  A list of supplementary group names to run _script_ and _postStartScript_ under. Default `[]`.

* _userGroups_:
  A list of supplementary group names to run _script_ and _postStartScript_ under. Default `[]`. These groups will be created if they do not already exist.

* _home_:
  The `$HOME` of _name_. If `null`, `/var/empty` will be used. Default `null`.

* _createHome_:
  If `true`, _home_ exists, is owned by _name_:_name_ and is the working directory for _script_. Contents not guaranteed to be owned by _name_. Will not move contents with _home_. Default `true` if _home_ is non-`null`, else `false`.

* _allowLogin_:
  If `true`, user shell is not `nologin`(8) and vice versa. Default `false`.

## RETURN VALUE

Returns an attrset of service representations.

* `attrs`:
  The arguments passed to `mkService`. Useful for later introspection.

* `serviceAttr`:
  An attrset with a single attribute. The name of the attribute is _name_, and the value is a service description suitable for use with `systemd.services` in NixOS. Used like `{ systemd.services = proxy-service.serviceAttr // simple-http-server.serviceAttr; }`.

* `disnix`:
  A Disnix service description suitable for use in a Disnix "services.nix".

* `script`:
  A Bash script that runs the service. Note the script will not clean the environment before starting.

* `exports`:
  _exports_, unaltered.

## SECURITY

Do not store secrets or credentials in a service description. These details will likely end up in the Nix store, which is world-readable. The same applies to packages used by the service.

## EXAMPLE

```
{mkService, python3, proxy-service}:

simple-http-server = mkService {
  name = "simple-http-server";
  description = "A server that serves itself.";
  dependsOn = [ proxy-service ];
  path = [ python3 ];
  environment.PORT = "8000";
  script = ''
    cd ${./.}
    python3 -m http.server $PORT
  '';
};
```

## NOTES

The behaviour of `disenv`(1) given conflicting user descriptions is undefined. `checkServices`(3) can validate an attrset of services does not have this issue.

## BUGS

`script` does not properly execute _postStartScript_.

## SEE ALSO

`disenv`(1), `systemd.service`(5), `checkServices`(3)
