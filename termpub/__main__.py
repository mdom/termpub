from pathlib import Path
import argparse
import curses
import locale
import os
import shlex
import sys
import zipfile

from termpub.commands import parse_command, CommandException 
from termpub.reader import Reader
import termpub.epub as epub_parser
import termpub.readline as readline
import termpub.renderer as renderer
import termpub.width as width

locale.setlocale(locale.LC_ALL, '')
code = locale.getpreferredencoding()

class ConfigError(Exception):
    pass

def die(msg):
    print('termpub:', msg, file=sys.stderr)
    sys.exit(1)

def enter_curses(stdscr, epub, config, keys):
    curses.raw()
    reader = Reader(epub, stdscr, **config)
    reader.keys = { **reader.keys, **keys }
    reader.update()

def find_config_file():
    config_home = os.environ.get(
        'XDG_CONFIG_HOME', os.path.expanduser('~/.config/'))
    return os.path.join(config_home,'termpub','termpubrc')

def read_config_file(config_file):
    dict = {}
    keys = {}
    with open(config_file) as f:
        for line in f:
            try:
                command, *args = parse_command(line)
            except CommandException as e:
                die(e.msg)

            if command == 'set':
                dict[args[0]] = args[1]
            elif command == 'map':
                keys[args[0]] = args[1]
    return dict, keys

def start_cli():

    parser = argparse.ArgumentParser(description="View epubs")
    parser.add_argument('file', metavar='FILE', help='Epub to display')
    parser.add_argument(
        '--hyphenate', action='store_true', help='hyphenate text' )
    parser.add_argument('--language', help='set language for hyphenation')
    parser.add_argument('--width', type=int, help='set width')
    parser.add_argument(
        '--dump', action='store_true', help='dump rendered epub to stdout')

    defaults = {
        'width': 80,
        'language': 'en_US',
    }
    keys = {}
    config = {}

    config_file = find_config_file()
    if config_file and os.path.isfile(config_file):
        config, keys = read_config_file(config_file)

    defaults = {**defaults, **config}
    parser.set_defaults(**defaults)

    args = parser.parse_args()
    args = vars(args)

    file = args['file']
    del args['file']

    try:
        epub = epub_parser.Epub(file)
    except (zipfile.BadZipFile, IsADirectoryError, FileNotFoundError) as e:
        die(f'"{file}" is not an epub file.')

    if args.get('dump'):
        from termpub.renderer import Renderer
        for chapter in epub.chapters:
            lines, _, _ = Renderer().render(chapter.source)
            for line in lines:
                print(line)
        sys.exit(0)
    del args['dump']

    if args.get('dbfile') is None:
        xdg_data_dir = Path(
            os.environ.get(
                'XDG_DATA_HOME', os.path.expanduser('~/.local/share/')),
            'termpub')
        xdg_data_dir.mkdir(parents=True, exist_ok=True)
        args['dbfile'] = str(xdg_data_dir.joinpath('termpub.sqlite'))

    curses.wrapper(enter_curses, epub, args, keys)

def main():
    try:
        start_cli()
    except BrokenPipeError:
        devnull = os.open(os.devnull, os.O_WRONLY)
        os.dup2(devnull, sys.stdout.fileno())
        sys.exit(1)

if __name__ == "__main__":
    main()
