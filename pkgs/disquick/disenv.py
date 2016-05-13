#!python3

import argparse
import json
import os
import os.path
import shutil
import subprocess
import sys
import tempfile

sys.path.append('libexec')

import argparse2man
from cached_property import cached_property

__description__ = 'Installs or updates the service environment of a remote system'

class Remote():
    def __init__(self, target, system, tempdir, ssh_user=None):
        if ssh_user is None:
            ssh_user = env.get('SSH_USER', env['USER'])
        self.ssh_user = ssh_user
        self.target = target
        self.system = system
        self.tempdir = tempdir

    @cached_property
    def env(self):
        env = os.environ.copy()
        env['TMPDIR'] = '/tmp'
        env['DISNIX_IMPORT_SUDO'] = 'true'
        env['SSH_USER'] = self.ssh_user
        return env

    @cached_property
    def infrastructure(self):
        return writefile(self.tempdir + "/infrastructure.nix", mk_infrastructure(self.target, self.system))

    @cached_property
    def local_profile_path(self):
        d = os.path.expanduser('~/.local/share/disenv/') + self.target
        os.makedirs(d, exist_ok=True, mode=0o700)
        return d

    @cached_property
    def remote_profile_path(self):
        return '{}@{}:/var/lib/disenv/coordinator-profile'.format(self.ssh_user, self.target)

    def _run_disnix(self, cmd, **kwargs):
        subprocess.check_call(['nix-shell', '-p', 'disnix', '--run', cmd], env=self.env, **kwargs)

    def _rsync(self, here, there):
        subprocess.check_call(['rsync', '-rl', here + '/', there])

    def _sync_coordinator_profile(self, dir_flag):
        for name in filter(lambda n: n != 'default', os.listdir(self.local_profile_path)):
            nix_store_path = os.readlink(self.local_profile_path + '/' + name)
            cmd = 'disnix-copy-closure {} -t {} {}'.format(dir_flag, self.target, nix_store_path)
            self._run_disnix(cmd)

    def pull_coordinator_profile(self):
        self._rsync(self.remote_profile_path, self.local_profile_path)
        self._sync_coordinator_profile('--from')

    def push_coordinator_profile(self):
        self._rsync(self.local_profile_path, self.remote_profile_path)
        self._sync_coordinator_profile('--to')

    def deploy(self, services, distribution):
        cmd = 'disnix-env -i "{}" -d "{}" -s "{}" --show-trace --build-on-targets --coordinator-profile-path {}'.format(self.infrastructure, distribution, services, self.local_profile_path)
        self._run_disnix(cmd)

def mk_infrastructure(hostname, system):
    return """{{ target = {{ hostname = "{}"; system = "{}"; }}; }}""".format(hostname, system)

def mk_distribution(service_names):
    return "{{infrastructure}}: {{ {} }}".format(" ".join(n + " = builtins.attrValues infrastructure;" for n in service_names))

def mk_services(filename, infrastructure):
    return "{{system, pkgs, distribution, invDistribution}}: pkgs.lib.mapAttrs' (name: s: {{ name = s.attrs.name; value = s.disnix; }}) (import {} {{ inherit pkgs; infrastructure = import {}; }})".format(filename, infrastructure)

def writefile(fn, content, end="\n"):
    with open(fn, "w") as f:
        f.write(content)
        if end:
            f.write(end)
    return fn

def get_service_names(filename, infrastructure):
    expr = "with import <nixpkgs> {{}}; builtins.toJSON (lib.mapAttrsToList (n: s: s.attrs.name) (import {} {{ inherit pkgs; infrastructure = import {}; }}))".format(filename, infrastructure)
    out = subprocess.check_output(["nix-instantiate", "--show-trace", "--eval", "--expr", expr], universal_newlines=True)
    in_string = json.loads(out)
    return json.loads(in_string)

def run(filename, target, system, tempdir, ssh_user=None):
    filename = os.path.abspath(filename)

    remote = Remote(target, system, tempdir, ssh_user=ssh_user)

    service_names = get_service_names(filename, remote.infrastructure)
    distribution = writefile(tempdir + "/distribution.nix", mk_distribution(service_names))
    services = writefile(tempdir + "/services.nix", mk_services(filename, remote.infrastructure))

    print('[disenv]: Retrieving coordinator profile from remote')
    remote.pull_coordinator_profile()

    try:
        remote.deploy(services, distribution)
    finally:
        print('[disenv]: Sending coordinator profile to remote')
        remote.push_coordinator_profile()

def main(argv):
    parser = argparse2man.new_parser(__description__)
    parser.add_argument("-s", "--services", help="services.nix file", required=True, metavar='services.nix')
    # parser.add_argument("-i", "--infrastructure", help="infrastructure.nix file")
    parser.add_argument("-t", "--target", help="Target hostname", required=True)
    parser.add_argument("-y", "--system", help="Target system (i686-linux, armv7l-linux, ..)", required=True)
    parser.add_argument("--ssh-user", help="User to SSH into")
    parser.add_argument("--tempdir", help="Temporary directory to store generated files")
    args = parser.parse_args(argv)

    with tempfile.TemporaryDirectory() as d:
        tempdir = os.path.abspath(args.tempdir or d)
        run(args.services, args.target, args.system, tempdir, ssh_user=args.ssh_user)

if __name__ == '__main__':
    main(sys.argv[1:])
