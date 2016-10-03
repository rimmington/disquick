#!python3

import argparse
import os.path
import sys
import tempfile

sys.path.append('libexec/disquick')

import argparse2man
import disquick

__description__ = 'Installs or updates the service environment of a remote system'

def run(filename, target, system, ssh_user=None, keep_only=None, build_on_remote=True, use_binary_caches=None):
    filename = os.path.abspath(filename)

    remote = disquick.Remote(target, system, ssh_user=ssh_user)
    deployment = disquick.Deployment(filename, remote, build_on_remote=build_on_remote)
    deployment.deploy(keep_only=keep_only)

def main(argv):
    parser = argparse2man.new_parser(__description__)
    parser.add_argument('-s', '--services', help='services.nix file', required=True, metavar='services.nix')
    # parser.add_argument('-i', '--infrastructure', help='infrastructure.nix file')
    parser.add_argument('-t', '--target', help='Target hostname', required=True)
    parser.add_argument('-y', '--system', help='Target system (x86_64-linux, armv7l-linux, ..)', required=True)
    parser.add_argument('--ssh-user', help='User to SSH into')
    parser.add_argument('--keep-only', help='Number of generations to keep (default 5, 0 to keep all)', type=int, default=5)
    parser.add_argument('--no-build-on-target', help='Do not build any derivations on target', action='store_true')
    parser.add_argument('--no-binary-caches', help='Do not use any binary caches', action='store_true')

    args = parser.parse_args(argv)
    run(args.services, args.target, args.system
        , ssh_user=args.ssh_user
        , keep_only=args.keep_only if args.keep_only else None
        , build_on_remote=not args.no_build_on_target
        , use_binary_caches=False if args.no_binary_caches else None)

if __name__ == '__main__':
    main(sys.argv[1:])
