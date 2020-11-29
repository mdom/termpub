# TODO search
from pathlib import Path
import argparse
import curses
import locale
import os
import shlex
import sys

from termpub.reader import Reader
import termpub.epub as epub_parser
import termpub.readline as readline
import termpub.renderer as renderer
import termpub.width as width

locale.setlocale(locale.LC_ALL, '')
code = locale.getpreferredencoding()

class ConfigError(Exception):
    pass

def enter_curses(stdscr, file, config):
    epub = epub_parser.Epub(file)
    curses.raw()
    Reader(epub, stdscr, **config).update()

def find_config_file():
    config_home = os.environ.get(
        'XDG_CONFIG_HOME', os.path.expanduser('~/.config/'))
    return os.path.join(config_home,'termpub','termpubrc')

def read_config_file(config_file):
    dict = {}
    with open(config_file) as f:
        for line in f:
            command, *args = shlex.split(line, comments=True)
            if command == 'set':
                if len(args) == 2:
                    if args[1] in ('1', 'true', 'on'):
                        args[1] = True
                    elif args[1] in ('0', 'false', 'off'):
                        args[1] = False
                    dict[args[0]] = args[1]
                else:
                    raise ConfigError(f'Wrong number of arguments: {line}')
            else:
                raise ConfigError(
                    f'Unknown command "{command}" in "{config_file}"')
    return dict

def main():

    parser = argparse.ArgumentParser(description="View epubs")
    parser.add_argument('file', metavar='FILE', help='Epub to display')
    parser.add_argument(
        '--hyphenate', action='store_true', help='hyphenate text' )
    parser.add_argument('--language', help='set language for hyphenation')
    parser.add_argument('--width', type=int, help='set width')

    defaults = {
        'width': 80,
        'language': 'en_US',
    }
    config_file = find_config_file()
    try:
        if config_file:
            config = read_config_file(config_file)
    except ConfigError as msg:
        print(msg, file=sys.stderr)
        sys.exit(1)

    defaults = {**defaults, **config}
    parser.set_defaults(**defaults)

    args = parser.parse_args()
    args = vars(args)

    file = args['file']
    del args['file']

    if args.get('dbfile') is None:
        xdg_data_dir = Path(
            os.environ.get(
                'XDG_DATA_HOME', os.path.expanduser('~/.local/share/')),
            'termpub')
        xdg_data_dir.mkdir(parents=True, exist_ok=True)
        args['dbfile'] = str(xdg_data_dir.joinpath('termpub.sqlite'))

    curses.wrapper(enter_curses, file, args)

if __name__ == "__main__":
    try:
        main()
    except FileNotFoundError as msg:
        print(msg, file=sys.stderr)
    except BrokenPipeError:
        devnull = os.open(os.devnull, os.O_WRONLY)
        os.dup2(devnull, sys.stdout.fileno())
        sys.exit(1)
