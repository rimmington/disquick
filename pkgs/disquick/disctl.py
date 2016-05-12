#!python3

import argparse
import os
import subprocess
import sys

sys.path.append('libexec')

import argparse2man

__description__ = 'View and modify local service state'

def find_service(name, lines, start):
    for l in lines:
        if l.endswith('.service') and l[start:-8] == name:
            return l
    return None

def disnix_running():
    try:
        subprocess.check_call(['systemctl', 'status', 'disnix.service'], stdout=subprocess.DEVNULL)
    except subprocess.CalledProcessError as e:
        if e.returncode == 3:
            return False
        else:
            raise
    else:
        return True

def det_service_full_name(pattern):
    if disnix_running():
        out = subprocess.check_output(['systemctl', 'list-dependencies', 'dysnomia.target'], universal_newlines=True)
        name = find_service(pattern, out.split('\n')[1:], 52)
        if name:
            return name[4:]
        else:
            return None
    else:
        return pattern

def subprocess_output(args):
    proc = subprocess.Popen(args, universal_newlines=True, stdout=subprocess.PIPE)
    (stdout, stderr) = proc.communicate()
    return stdout

def colour(colour, msg):
    return '\033[{}{}\033[0m'.format(colour, msg)

RED = '38;5;196m'

def print_system_status():
    subprocess.check_call(['systemctl', 'status'])
    if subprocess_output(['systemctl', 'is-system-running']).strip() == 'degraded':
        print('\nSome units have {}:'.format(colour(RED, 'failed')))
        # Strip systemctl help footer
        subprocess.check_call('SYSTEMD_COLORS=1 systemctl --failed | head -n-3', shell=True)

def main(argv):
    parser = argparse2man.new_parser(__description__)
    parser.add_argument('service', help='Service name, without any Disnix prefix', nargs='?', metavar='SERVICE')
    actions = parser.add_mutually_exclusive_group()
    actions.add_argument('-l', '--start', help='Launch the service', action='store_true')
    actions.add_argument('-e', '--stop', help='End the service', action='store_true')
    actions.add_argument('-j', '--journal', help='Show service journal', action='store_true')
    actions.add_argument('--clear-failed', help='Clear one or all failed services', action='store_true')
    args = parser.parse_args(argv)

    if not args.service:
        if args.clear_failed:
            sys.exit(subprocess.call(['sudo', 'systemctl', 'reset-failed']))
        else:
            print_system_status()
            return

    name = det_service_full_name(args.service)
    if not name:
        print('Unknown service ' + args.service)
        sys.exit(1)
    elif args.start:
        sys.exit(subprocess.call(['sudo', 'systemctl', 'start', name]))
    elif args.stop:
        sys.exit(subprocess.call(['sudo', 'systemctl', 'stop', name]))
    elif args.journal:
        sys.exit(subprocess.call(['sudo', 'journalctl', '-u', name]))
    elif args.clear_failed:
        sys.exit(subprocess.call(['sudo', 'systemctl', 'reset-failed', name]))
    else:
        sys.exit(subprocess.call(['systemctl', 'status', name]))

if __name__ == '__main__':
    main(sys.argv[1:])
