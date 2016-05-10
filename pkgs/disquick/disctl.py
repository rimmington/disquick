#!python3

import argparse
import subprocess
import sys

def find_service(name, lines, start):
    for l in lines:
        if l.endswith('.service') and l[start:-8] == name:
            return l
    return None

def disnix_running():
    try:
        subprocess.check_call(['systemctl', 'list-units', 'disnix.service'], stdout=subprocess.DEVNULL)
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

def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument('service', help='Service name, without any Disnix prefix', nargs='?')
    actions = parser.add_mutually_exclusive_group()
    actions.add_argument('-l', '--start', help='Launch the service', action='store_true')
    actions.add_argument('-e', '--stop', help='End the service', action='store_true')
    actions.add_argument('-j', '--journal', help='Show service journal', action='store_true')
    args = parser.parse_args(argv)

    if not args.service:
        sys.exit(subprocess.call(['systemctl', 'status']))

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
    else:
        sys.exit(subprocess.call(['systemctl', 'status', name]))

if __name__ == '__main__':
    main(sys.argv[1:])
