import json
import os
import os.path
import subprocess
import xml.etree.ElementTree as xml

from cached_property import cached_property

# TODO: Use logging
# FIXME: run all in nix-shell OR set PATH in env

def writefile(fn, content, end='\n'):
    with open(fn, 'w') as f:
        f.write(content)
        if end:
            f.write(end)
    return fn

class DisnixEnvironment():
    def __init__(self, ssh_user=None):
        self.ssh_user = ssh_user
        if not self.ssh_user:
            self.ssh_user = os.environ.get('SSH_USER')
        if not self.ssh_user:
            self.ssh_user = os.environ.get('USER')
        if not self.ssh_user:
            raise ValueError('ssh_user not specified and cannot be determined from environment')

    @cached_property
    def env(self):
        env = os.environ.copy()
        env['TMPDIR'] = '/tmp'
        env['DISNIX_IMPORT_SUDO'] = 'true'
        env['SSH_USER'] = self.ssh_user
        return env

    def run(self, cmd, output=False, **kwargs):
        stdout = subprocess.PIPE if output else None
        res = subprocess.run(['nix-shell', '-p', 'disnix', '--run', cmd], env=self.env, stdout=stdout, check=True, universal_newlines=True, **kwargs)
        if output:
            return res.stdout.strip()

class Remote():
    def __init__(self, target, system, tempdir, ssh_user=None):
        disnix_environment = DisnixEnvironment(ssh_user)
        self.ssh_user = disnix_environment.ssh_user
        self.run_disnix = disnix_environment.run
        self.target = target
        self.system = system
        self.tempdir = tempdir

    @classmethod
    def from_manifest_file(cls, manifest, tempdir, ssh_user=None):
        root = xml.parse(manifest).getroot()
        target = root.find('./targets/target')
        hostname = target.find('hostname').text
        system = target.find('system').text
        return cls(hostname, system, tempdir, ssh_user=ssh_user)

    def coordinator_profile(self):
        return SyncingCoordinatorProfile(self)

class Deployment():
    def __init__(self, filename, remote, tempdir, build_on_remote=True):
        self.filename = filename
        self.remote = remote
        self.tempdir = tempdir
        self.build_on_remote = build_on_remote

    def _call_manifest(self, attr):
        expr = 'let pkgs = import <nixpkgs> {{}}; system = "{}"; serviceSet = import {} {{ pkgs = import <nixpkgs> {{ inherit system; }}; inherit (props) infrastructure; }}; props = (pkgs.callPackage libexec/disquick/manifest.nix {{}}) {{ inherit serviceSet system; hostname = "{}"; }}; in props.{}'.format(self.remote.system, self.filename, self.remote.target, attr)
        return subprocess.check_output(['nix-build', '--no-out-link', '--show-trace', '-E', expr], universal_newlines=True).strip()

    def _build_on_remote(self):
        print('[coordinator]: Instantiating store derivations')
        distributed_derivation = self._call_manifest('distributedDerivation')
        # distributedDerivation=`disnix-instantiate -s $servicesFile -i $infrastructureFile -d $distributionFile --target-property $targetProperty --interface $interface --no-out-link $showTraceArg`
        print('[coordinator]: Building store derivations')
        self.remote.run_disnix('disnix-build ' + distributed_derivation)
        # disnix-build $maxConcurrentTransfersArg $distributedDerivation

    @cached_property
    def _manifest(self):
        if self.build_on_remote:
            self._build_on_remote()

        print('[coordinator]: Building manifest')
        return Manifest(self._call_manifest('manifest'), self.remote.run_disnix)
        # manifest=`disnix-manifest -s $servicesFile -i $infrastructureFile -d $distributionFile --target-property $targetProperty --no-out-link --interface $interface $deployStateArg $showTraceArg`

    def manifest(self):
        return self._manifest

    def deploy(self):
        manifest = self.manifest()
        with self.remote.coordinator_profile() as p:
            manifest.deploy(p)

class Manifest():
    def __init__(self, filename, run_disnix):
        self.filename = filename
        self.run_disnix = run_disnix

    def _locks(self):
        return Locks(self.filename, self.run_disnix)

    def _distribute(self):
        print('[coordinator]: Distributing intra-dependency closures')
        self.run_disnix('disnix-distribute ' + self.filename)
        # disnix-distribute $maxConcurrentTransfersArg $manifest

    def _activate(self, coordinator_profile):
        print('[coordinator]: Activating new configuration')
        self.run_disnix('disnix-activate --coordinator-profile-path {} {}'.format(coordinator_profile, self.filename))
        # disnix-activate $profileArg $coordinatorProfilePathArg $noUpgradeArg $manifest || (releaseLocks; displayFailure; exit 1)

    def _set(self, coordinator_profile):
        print('[coordinator]: Setting profiles')
        self.run_disnix('disnix-set --coordinator-profile-path {} {}'.format(coordinator_profile, self.filename))
        # disnix-set $profileArg $coordinatorProfilePathArg $noCoordinatorProfileArg $noTargetProfilesArg $manifest || (releaseLocks; displayFailure; exit 1)

    def deploy(self, coordinator_profile):
        # NOTE: Does not sync coordinator profiles. Expected to run on single machine.
        self._distribute()
        with self._locks():
            self._activate(coordinator_profile.local_path)
            self._set(coordinator_profile.local_path)
        print('[coordinator]: The system has been successfully deployed!')

class Locks():
    def __init__(self, manifest, run_disnix):
        self.manifest = manifest
        self.run_disnix = run_disnix

    def __enter__(self):
        print('[coordinator]: Acquiring locks')
        self.run_disnix('disnix-lock ' + self.manifest)
        # disnix-lock $profileArg $manifest || (displayFailure; exit 1)

    def __exit__(self, *exc_details):
        print('[coordinator]: Releasing locks')
        self.run_disnix('disnix-lock --unlock ' + self.manifest)
        # disnix-lock --unlock $profileArg $manifest
        return False  # Don't suppress any exception

class SyncingCoordinatorProfile():
    def __init__(self, remote):
        self.remote = remote

    @cached_property
    def local_path(self):
        d = os.path.expanduser('~/.local/share/disenv/') + self.remote.target
        os.makedirs(d, exist_ok=True, mode=0o700)
        return d

    @cached_property
    def remote_path(self):
        return '{}@{}:/var/lib/disenv/coordinator-profile'.format(self.remote.ssh_user, self.remote.target)

    def __enter__(self):
        # FIXME: This goes linear in the number of deployments
        print('[coordinator]: Retrieving coordinator profile from remote')
        self._rsync(self.remote_path, self.local_path)
        self._sync_coordinator_profile('--from')
        return self

    def __exit__(self, *exc_details):
        print('[coordinator]: Sending coordinator profile to remote')
        self._rsync(self.local_path, self.remote_path)
        self._sync_coordinator_profile('--to')
        return False  # Don't suppress any exception

    def _rsync(self, here, there):
        subprocess.check_call(['rsync', '-rl', here + '/', there])

    def _sync_coordinator_profile(self, dir_flag):
        for name in filter(lambda n: n != 'default', os.listdir(self.local_path)):
            nix_store_path = os.readlink(self.local_path + '/' + name)
            cmd = 'disnix-copy-closure {} -t {} {}'.format(dir_flag, self.remote.target, nix_store_path)
            self.remote.run_disnix(cmd)
