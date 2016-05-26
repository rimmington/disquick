import json
import os
import os.path
import subprocess
import tempfile
import xml.etree.ElementTree as xml

from cached_property import cached_property

# TODO: Use logging

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
        # Not using nix-shell because it wants nixpkgs available, which we don't want to require when using 'dispro activate'
        env['PATH'] = 'PATH_TO(disnix)/bin:PATH_TO(nix)/bin:PATH_TO(openssh)/bin:' + env['PATH']
        return env

    def run(self, cmd, output=False, **kwargs):
        stdout = subprocess.PIPE if output else None
        res = subprocess.run(cmd, env=self.env, stdout=stdout, check=True, universal_newlines=True, **kwargs)
        if output:
            return res.stdout.strip()

class Remote():
    def __init__(self, target, system, ssh_user=None):
        disnix_environment = DisnixEnvironment(ssh_user)
        self.ssh_user = disnix_environment.ssh_user
        self.run_disnix = disnix_environment.run
        self.target = target
        self.system = system

    @classmethod
    def from_manifest_file(cls, manifest, ssh_user=None):
        root = xml.parse(manifest).getroot()
        target = root.find('./targets/target')
        hostname = target.find('hostname').text
        system = target.find('system').text
        return cls(hostname, system, ssh_user=ssh_user)

    def coordinator_profile(self):
        return SyncingCoordinatorProfile(self)

    def run_gc(self):
        with tempfile.TemporaryDirectory() as d:
            infrastructure = writefile(d + '/infrastructure.nix', '{{ target = {{ hostname = "{}"; system = "{}"; }}; }}'.format(self.target, self.system))
            self.run_disnix(['disnix-collect-garbage', '-d', infrastructure])

class Deployment():
    def __init__(self, filename, remote, build_on_remote=True):
        self.filename = filename
        self.remote = remote
        self.build_on_remote = build_on_remote

    def _call_manifest(self, attr):
        expr = 'let pkgs = import <nixpkgs> {{}}; system = "{}"; serviceSet = import {} {{ pkgs = import <nixpkgs> {{ inherit system; }}; inherit (props) infrastructure; }}; props = (pkgs.callPackage libexec/disquick/manifest.nix {{}}) {{ inherit serviceSet system; hostname = "{}"; }}; in props.{}'.format(self.remote.system, self.filename, self.remote.target, attr)
        return subprocess.check_output(['PATH_TO(nix)/bin/nix-build', '--no-out-link', '--show-trace', '-E', expr], universal_newlines=True).strip()

    def _build_on_remote(self):
        print('[coordinator]: Instantiating store derivations')
        distributed_derivation = self._call_manifest('distributedDerivation')
        # distributedDerivation=`disnix-instantiate -s $servicesFile -i $infrastructureFile -d $distributionFile --target-property $targetProperty --interface $interface --no-out-link $showTraceArg`
        # disnix-build fails when there's no services to build
        if xml.parse(distributed_derivation).getroot().findall('./build/'):
            print('[coordinator]: Building store derivations')
            self.remote.run_disnix(['disnix-build', distributed_derivation])
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
        self.run_disnix(['disnix-distribute', self.filename])
        # disnix-distribute $maxConcurrentTransfersArg $manifest

    def _activate(self, coordinator_profile):
        print('[coordinator]: Activating new configuration')
        self.run_disnix(['disnix-activate', '--coordinator-profile-path', coordinator_profile, self.filename])
        # disnix-activate $profileArg $coordinatorProfilePathArg $noUpgradeArg $manifest || (releaseLocks; displayFailure; exit 1)

    def _set(self, coordinator_profile):
        print('[coordinator]: Setting profiles')
        self.run_disnix(['disnix-set', '--coordinator-profile-path', coordinator_profile, self.filename])
        # disnix-set $profileArg $coordinatorProfilePathArg $noCoordinatorProfileArg $noTargetProfilesArg $manifest || (releaseLocks; displayFailure; exit 1)

    def deploy(self, coordinator_profile):
        # NOTE: Does not sync coordinator profiles. Expected to run on single machine.
        self._distribute()
        with self._locks():
            self._activate(coordinator_profile.local_path)
            self._set(coordinator_profile.local_path)
        print('[coordinator]: The system has been successfully deployed!')

    def create_gc_root(self, path):
        subprocess.check_call(['PATH_TO(nix)/bin/nix-store', '--max-jobs', '0', '-r', '--add-root', path, '--indirect', self.filename])

class Locks():
    def __init__(self, manifest, run_disnix):
        self.manifest = manifest
        self.run_disnix = run_disnix

    def __enter__(self):
        print('[coordinator]: Acquiring locks')
        self.run_disnix(['disnix-lock', self.manifest])
        # disnix-lock $profileArg $manifest || (displayFailure; exit 1)

    def __exit__(self, *exc_details):
        print('[coordinator]: Releasing locks')
        self.run_disnix(['disnix-lock', '--unlock', self.manifest])
        # disnix-lock --unlock $profileArg $manifest
        return False  # Don't suppress any exception

class SyncingCoordinatorProfile():
    TARGET_COORDINATOR_PROFILE_DIR = '/var/lib/disenv/coordinator-profile'

    def __init__(self, remote):
        self.remote = remote

    @cached_property
    def local_path(self):
        d = os.path.expanduser('~/.local/share/disenv/') + self.remote.target
        os.makedirs(d, exist_ok=True, mode=0o700)
        return d

    @cached_property
    def remote_path(self):
        return '{}@{}:{}'.format(self.remote.ssh_user, self.remote.target, self.TARGET_COORDINATOR_PROFILE_DIR)

    def current_local(self, must_exist=True):
        default = self.local_path + '/default'
        if os.path.exists(default):
            return self.local_path + '/' + os.readlink(default)
        elif must_exist:
            raise FileNotFoundError(default)
        else:
            return None

    def delete_generations(self, keep_count, sync=True):
        current = self.current_local()
        current_num = int(os.path.basename(current).split('-')[1])
        keep = ['default-{}-link'.format(n) for n in range(current_num, 0, -1)[:keep_count]] + ['default']
        old = sorted(f for f in os.listdir(self.local_path) if f not in keep)
        if old:
            print('[coordinator]: Deleting generations ' + ' '.join(old))
        else:
            print('[coordinator]: No generations will be deleted')

        for fn in old:
            os.unlink(self.local_path + '/' + fn)

        if sync:
            self._push_profile()

    def _push_profile(self):
        print('[coordinator]: Sending coordinator profile to remote')
        self._rsync(self.local_path, self.remote_path)
        self._sync_coordinator_profile('--to')
        subprocess.check_call(['PATH_TO(openssh)/bin/ssh', '{}@{}'.format(self.remote.ssh_user, self.remote.target), 'find {}/*-link | while read x; do nix-store --max-jobs 0 -r --add-root $x --indirect $(readlink $x); done'.format(self.TARGET_COORDINATOR_PROFILE_DIR)])

    def __enter__(self):
        # FIXME: This goes linear in the number of deployments
        print('[coordinator]: Retrieving coordinator profile from remote')
        self._rsync(self.remote_path, self.local_path)
        self._sync_coordinator_profile('--from')
        return self

    def __exit__(self, *exc_details):
        self._push_profile()
        return False  # Don't suppress any exception

    def _rsync(self, here, there):
        subprocess.check_call(['PATH_TO(rsync)/bin/rsync', '-rl', '--delete-after', here + '/', there])

    def _sync_coordinator_profile(self, dir_flag):
        for name in filter(lambda n: n != 'default', os.listdir(self.local_path)):
            nix_store_path = os.readlink(self.local_path + '/' + name)
            self.remote.run_disnix(['disnix-copy-closure', dir_flag, '-t', self.remote.target, nix_store_path])
