mkService(3) - realise a service description in a number of formats
===================================================================

## SYNOPSIS

**pkgs.mkService {** name, script, preStartRootScript, postStartScript, description, startWithBoot, restartOnFailure, restartOnSuccess, user, dependsOn, environment, path, network, killMode, exports **} -> {** attrs, serviceAttr, disnix, script, exports **}**

## DESCRIPTION

`mkService` transforms a description of a system service into descriptions for NixOS and Disnix as well as a shell script.

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

* _restartOnFailure_:
  Whether to restart the service if it fails. Restarts are throttled, so this won't restart endlessly. See `systemd.service`(5) for more details on what "failure" means. Default `true`.

* _restartOnSuccess_:
  Whether to restart the service if it terminates cleanly. Default `false`.

* _dependsOn_:
  A list of other services this service must be started after. Values of the list are other `mkService` return values. Default `[]` (empty).

* _killMode_:
  See `systemd.service`(5). Accepts "control-group" or "process". Default "control-group".

### Environment arguments

* _environment_:
  An attrset of environment variables available to each of the service scripts.

* _path_:
  A list of packages. The `bin` directory of each package is included in the `PATH` environment variable.

* _network_:
  Whether the service uses the network. If `false`, the service runs in its own network namespace with a single private loopback interface. Default `true`.

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
