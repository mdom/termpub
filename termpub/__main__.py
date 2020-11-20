# TODO search
from pathlib import Path
import argparse
import configparser
import curses
import locale
import os
import sys

from termpub.reader import Reader
import termpub.epub as epub_parser
import termpub.readline as readline
import termpub.renderer as renderer
import termpub.width as width

locale.setlocale(locale.LC_ALL, '')
code = locale.getpreferredencoding()

def enter_curses(stdscr,epub, args):
    curses.raw()
    Reader(epub,stdscr, args).update()

def find_config_file():
    config_home = os.environ.get(
        'XDG_CONFIG_HOME', os.path.expanduser('~/.config/'))
    return os.path.join(config_home,'termpub','config.ini')

def main():

    parser = argparse.ArgumentParser(description="View epubs")
    parser.add_argument('file', metavar='FILE', help='Epub to display')
    parser.add_argument('--dump-source', action='store_true' )
    parser.add_argument('--hyphenate', action='store_true' )
    parser.add_argument('--language')
    parser.add_argument('--width')

    config_file = find_config_file()

    config = None
    if config_file:
        config = configparser.ConfigParser()
        config.read(config_file)

        if config.has_section('termpub'):
            parser.set_defaults(
                hyphenate=config.getboolean('termpub', 'hyphenate', fallback=False),
                language=config.get('termpub', 'language', fallback='en_US'),
                width=config.get('termpub', 'width', fallback='80'),
            )


    args = parser.parse_args()

    args = vars(args)

    if config and config.has_section('termpub'):
        status_left = config.get('termpub', 'status_left', fallback=None)
        if status_left:
            args['status_left'] = status_left

        status_right = config.get('termpub', 'status_right', fallback=None)
        if status_right:
            args['status_right'] = status_right

    if args.get('dbfile') is None:
        xdg_data_dir = Path(
            os.environ.get(
                'XDG_DATA_HOME', os.path.expanduser('~/.local/share/')),
            'termpub')
        xdg_data_dir.mkdir(parents=True, exist_ok=True)
        args['dbfile'] = xdg_data_dir.joinpath('termpub.sqlite')


    epub = epub_parser.Epub(args['file'])
    del args['file']

    if args.get('dump_source'):
        for chapter in epub.chapters():
            print(chapter.source)
        sys.exit(0);

    curses.wrapper(enter_curses, epub, args)

if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        devnull = os.open(os.devnull, os.O_WRONLY)
        os.dup2(devnull, sys.stdout.fileno())
        sys.exit(1)
