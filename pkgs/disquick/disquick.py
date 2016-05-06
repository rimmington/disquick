#!python3

import argparse
import json
import os
import subprocess
import sys
import tempfile

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
    out = subprocess.check_output(["nix-instantiate", "--eval", "--expr", expr], universal_newlines=True)
    in_string = json.loads(out)
    return json.loads(in_string)

def run(filename, infrastructure, tempdir, ssh_user=None):
    filename = os.path.abspath(filename)

    service_names = get_service_names(filename, infrastructure)
    distribution = writefile(tempdir + "/distribution.nix", mk_distribution(service_names))
    services = writefile(tempdir + "/services.nix", mk_services(filename, infrastructure))

    env = os.environ.copy()
    env['TMPDIR'] = '/tmp'
    env['DISNIX_IMPORT_SUDO'] = 'true'
    if ssh_user:
        env['SSH_USER'] = ssh_user
    subprocess.check_call(["disnix-env", "-i", infrastructure, "-d", distribution, "-s", services, "--show-trace", "--build-on-targets"], env=env)

def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--services", help="services.nix file", required=True)
    parser.add_argument("-i", "--infrastructure", help="infrastructure.nix file")
    parser.add_argument("-t", "--target", help="Target hostname")
    parser.add_argument("-y", "--system", help="Target system (i686-linux, armv7l-linux, ..)")
    parser.add_argument("--ssh-user", help="User to SSH into")
    parser.add_argument("--tempdir", help="Temporary directory to store generated files")
    args = parser.parse_args(argv[1:])

    with tempfile.TemporaryDirectory() as d:
        tempdir = os.path.abspath(args.tempdir or d)
        if args.infrastructure:
            infrastructure = args.infrastructure
        elif args.target and args.system:
            infrastructure = writefile(tempdir + "/infrastructure.nix", mk_infrastructure(args.target, args.system))
        else:
            print("You must specify --infrastructure or else both --target and --system")
            sys.exit(1)
        run(args.services, infrastructure, tempdir, ssh_user=args.ssh_user)

if __name__ == '__main__':
    main(sys.argv)
