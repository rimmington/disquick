#!python3

import argparse
import os.path
import sys
import tempfile

sys.path.append('libexec/disquick')

import argparse2man
import disquick

__description__ = 'Installs or updates the service environment of a remote system'

def run(filename, target, system, tempdir, ssh_user=None):
    filename = os.path.abspath(filename)

    remote = disquick.Remote(target, system, tempdir, ssh_user=ssh_user)
    deployment = disquick.Deployment(filename, remote, tempdir, build_on_remote=True)
    deployment.deploy()

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
