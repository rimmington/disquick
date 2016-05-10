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

__description__ = 'Installs or updates the service environment of a remote system'

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

def rsync_coordinator_profile(here, there):
    subprocess.check_call(['rsync', '-rl', here + '/', there])

def link_is_local(path):
    dest = os.readlink(path)
    d = os.path.dirname(dest)
    return d == '.' or d == '' or d == '_actual'

def copy_actual(path):
    os.makedirs(path + '/_actual', exist_ok=True)  # TODO: should be mode of parent
    for entry in os.scandir(path):
        if entry.name != '_actual' and not (entry.is_symlink() and link_is_local(entry.path)):
            actual = path + '/_actual/' + entry.name
            shutil.copy2(entry.path, actual, follow_symlinks=True)
            os.unlink(entry.path)
            os.symlink('_actual/' + entry.name, entry.path)

def get_remote_coordinator_profile(local, remote, user):
    rsync_coordinator_profile('{}@{}:/var/lib/disenv/coordinator-profile'.format(user, remote), local)

def update_remote_coordinator_profile(local, remote, user):
    copy_actual(local)
    rsync_coordinator_profile(local, '{}@{}:/var/lib/disenv/coordinator-profile'.format(user, remote))

def local_profile_dir(target):
    d = os.path.expanduser('~/.local/share/disenv/') + target
    os.makedirs(d, exist_ok=True, mode=0o700)
    return d

def run(filename, target, system, tempdir, ssh_user=None):
    filename = os.path.abspath(filename)

    infrastructure = writefile(tempdir + "/infrastructure.nix", mk_infrastructure(target, system))
    service_names = get_service_names(filename, infrastructure)
    distribution = writefile(tempdir + "/distribution.nix", mk_distribution(service_names))
    services = writefile(tempdir + "/services.nix", mk_services(filename, infrastructure))

    env = os.environ.copy()
    env['TMPDIR'] = '/tmp'
    env['DISNIX_IMPORT_SUDO'] = 'true'
    if ssh_user:
        env['SSH_USER'] = ssh_user
    else:
        ssh_user = env.get('SSH_USER', env['USER'])
    profile_path = local_profile_dir(target)

    print('[disenv]: Retrieving coordinator profile from remote')
    get_remote_coordinator_profile(profile_path, target, ssh_user)

    cmd = 'disnix-env -i "{}" -d "{}" -s "{}" --show-trace --build-on-targets --coordinator-profile-path {}'.format(infrastructure, distribution, services, profile_path)
    try:
        subprocess.check_call(['nix-shell', '-p', 'disnix', '--run', cmd], env=env)
    finally:
        print('[disenv]: Sending coordinator profile to remote')
        update_remote_coordinator_profile(profile_path, target, ssh_user)

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
    main(sys.argv)
