import argparse
import os
import sys

class Help2ManFormatter(argparse.RawDescriptionHelpFormatter):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._suppress = False
        self._width = sys.maxsize  # Suppress usage wrapping

    def start_section(self, heading):
        if heading == 'positional arguments':
            self._suppress = True
            return
        elif heading == 'optional arguments':
            heading = 'Options'

        super().start_section(heading)

    def end_section(self):
        if self._suppress:
            self._suppress = False
        else:
            super().end_section()

    def _add_item(self, func, args):
        if not self._suppress:
            super()._add_item(func, args)

    def add_usage(self, *args, prefix='Usage: '):
        super().add_usage(*args[:3], prefix=prefix)

def new_parser(description=None, version='1.0'):
    if os.environ.get('ARGPARSE2MAN_DESC'):
        print(description)
        sys.exit(0)

    for_man = bool(os.environ.get('MAN'))
    formatter_class = Help2ManFormatter if for_man else argparse.HelpFormatter
    epilog = None if for_man else 'See the man page for more details.'
    description = None if for_man else description

    parser = argparse.ArgumentParser(description=description, add_help=False, formatter_class=formatter_class, epilog=epilog)
    parser.add_argument('-h', '--help', action='help', help='Print a short help text and exit')
    parser.add_argument('--version', action='version', version='%(prog)s {}'.format(version), help='Print a short version string and exit')
    return parser
