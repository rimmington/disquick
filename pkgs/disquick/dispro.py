#!python3

import argparse
import os.path
import sys
import tempfile

import argparse2man
import disquick

__description__ = 'Low-level service distribution commands'

def run_manifest(args):
    filename = os.path.abspath(args.services)
    remote = disquick.Remote(args.target, args.system, ssh_user=args.ssh_user)
    deployment = disquick.Deployment(filename, remote
        , build_on_remote=not args.no_build_on_target
        , use_binary_caches=False if args.no_binary_caches else None)
    print(deployment.manifest().filename)

def run_activate(args):
    remote = disquick.Remote.from_manifest_file(args.manifest, ssh_user=args.ssh_user)
    manifest = disquick.Manifest(args.manifest, remote.run_disnix)
    coordinator_profile = remote.coordinator_profile()
    manifest.deploy(coordinator_profile)
    if args.gc_root:
        manifest.create_gc_root(coordinator_profile.current_local_generation_link())

def run_gc(args):
    remote = disquick.Remote(args.target, '', ssh_user=args.ssh_user)
    if args.keep_only:
        with remote.coordinator_profile() as p:
            p.delete_generations(args.keep_only)
    remote.run_gc()

def main(argv):
    parser = argparse2man.new_parser(__description__)
    parser.add_argument('--ssh-user', help='User to SSH into')
    subparsers = parser.add_subparsers(dest='command')
    subparsers.required = True

    manifest = subparsers.add_parser('manifest', help='Generate a Disnix manifest')
    manifest.add_argument('-s', '--services', help='services.nix file', required=True, metavar='services.nix')
    manifest.add_argument('-t', '--target', help='Target hostname', required=True)
    manifest.add_argument('-y', '--system', help='Target system (i686-linux, armv7l-linux, ..)', required=True)
    manifest.add_argument('--no-build-on-target', help='Do not build any derivations on target', action='store_true')
    manifest.add_argument('--no-binary-caches', help='Do not use any binary caches', action='store_true')
    manifest.set_defaults(func=run_manifest)

    activate = subparsers.add_parser('activate', help='Activate a Disnix manifest')
    activate.add_argument('--gc-root', help='Create local GC root symlink', action='store_true')
    activate.add_argument('manifest', help='Disnix manifest file')
    activate.set_defaults(func=run_activate)

    gc = subparsers.add_parser('gc', help='Run GC on target')
    gc.add_argument('--keep-only', help='Number of generations to keep', type=int)
    gc.add_argument('target', help='Target hostname')
    gc.set_defaults(func=run_gc)

    args = parser.parse_args(argv)
    args.func(args)

if __name__ == '__main__':
    main(sys.argv[1:])
