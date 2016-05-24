#!python3

import argparse
import os.path
import sys
import tempfile

import argparse2man
import disquick

__description__ = 'Low-level service distribution commands'

def run_manifest(args, tempdir):
    filename = os.path.abspath(args.services)
    remote = disquick.Remote(args.target, args.system, tempdir, ssh_user=args.ssh_user)
    deployment = disquick.Deployment(filename, remote, tempdir, build_on_remote=not args.no_build_on_target)
    print(deployment.manifest().filename)

def run_activate(args, tempdir):
    remote = disquick.Remote.from_manifest_file(args.manifest, tempdir, ssh_user=args.ssh_user)
    manifest = disquick.Manifest(args.manifest, remote.run_disnix)
    manifest.deploy(remote.coordinator_profile())

def main(argv):
    parser = argparse2man.new_parser(__description__)
    parser.add_argument('--ssh-user', help='User to SSH into')
    parser.add_argument('--tempdir', help='Temporary directory to store generated files')
    subparsers = parser.add_subparsers(dest='command')
    subparsers.required = True

    manifest = subparsers.add_parser('manifest', help='Generate a Disnix manifest')
    manifest.add_argument('-s', '--services', help='services.nix file', required=True, metavar='services.nix')
    manifest.add_argument('-t', '--target', help='Target hostname', required=True)
    manifest.add_argument('-y', '--system', help='Target system (i686-linux, armv7l-linux, ..)', required=True)
    manifest.add_argument('--no-build-on-target', help='Do not build any derivations on target', action='store_true')
    manifest.set_defaults(func=run_manifest)

    activate = subparsers.add_parser('activate', help='Activate a Disnix manifest')
    activate.add_argument('manifest', help='Disnix manifest file')
    activate.set_defaults(func=run_activate)

    args = parser.parse_args(argv)

    with tempfile.TemporaryDirectory() as d:
        tempdir = os.path.abspath(args.tempdir or d)
        args.func(args, tempdir)

if __name__ == '__main__':
    main(sys.argv[1:])
