#!python3

import argparse
import os.path
import sys
import tempfile

sys.path.append('libexec/disquick')

import argparse2man
import disquick

__description__ = 'Installs or updates the service environment of a remote system'

def run(filename, target, system, ssh_user=None, keep_only=None):
    filename = os.path.abspath(filename)

    remote = disquick.Remote(target, system, ssh_user=ssh_user)
    deployment = disquick.Deployment(filename, remote, build_on_remote=True)
    deployment.deploy(keep_only=keep_only)

def main(argv):
    parser = argparse2man.new_parser(__description__)
    parser.add_argument("-s", "--services", help="services.nix file", required=True, metavar='services.nix')
    # parser.add_argument("-i", "--infrastructure", help="infrastructure.nix file")
    parser.add_argument("-t", "--target", help="Target hostname", required=True)
    parser.add_argument("-y", "--system", help="Target system (x86_64-linux, armv7l-linux, ..)", required=True)
    parser.add_argument("--ssh-user", help="User to SSH into")
    parser.add_argument("--keep-only", help="Number of generations to keep (default 5, 0 to keep all)", type=int, default=5)

    args = parser.parse_args(argv)
    run(args.services, args.target, args.system, ssh_user=args.ssh_user, keep_only=args.keep_only if args.keep_only else None)

if __name__ == '__main__':
    main(sys.argv[1:])
