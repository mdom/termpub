from termpub.pager import Pager, TextPager
from termpub.renderer import Renderer
import curses
import json
import os
import os.path
import time
import posixpath
import sqlite3
import subprocess
import tempfile
import termpub.width as width
import urllib.parse

class Reader(Pager):

    def __init__(self, epub, stdscr, args):
        super().__init__(stdscr)

        self.epub = epub
        self.chapter = None
        self.chapters = self.epub.chapters()
        self.chapter_index = 0
        self.pads = [None] * len(self.chapters)
        self.pad = None
        self.current_line = 0
        self.title=epub.title
        self.locations = []
        self.args = args
        self.dbfile = args.get('dbfile')
        self.render_cache = {}

        self.dic=None
        if args.get('hyphenate'):
            if epub.language:
                lang = epub.language
            else:
                lang = args.get('language','en_US')
            try:
                import pyphen
                self.dic = pyphen.Pyphen(lang=lang)
            except ModuleNotFoundError:
                pass

        restored=0
        if self.dbfile and os.path.isfile(self.dbfile):
            position = self.load_state()
            if position:
                self.restore_position(position)
                restored = 1

        if not restored:
            self.load_start_chapter()

        self.keys = self.keys.copy()

        self.keys['>'] = 'next_chapter'
        self.keys['<'] = 'prev_chapter'
        self.keys['h'] = 'show_help'
        self.keys['t'] = 'goto_toc'
        self.keys['o'] = 'open_location'
        self.keys["m"] = 'save_marker'
        self.keys["'"] = 'goto_marker'

    def get_position(self):
        position = 0
        for idx, line in enumerate(self.lines):
            if idx <= self.y - 1:
                position += width.width(line)
            else:
                break
        position += 1
        return Position(self.chapter.file, position)

    def save_movement_marker(self):
        self.position["'"] = self.get_position()

    def restore_position(self, position):
        if self.load_chapter_by_file(position.file) is None:
            self.show_error("Can't restore position: file unknown.")

        if position is None:
            self.show_error('Position not set.')
            return

        if self.load_chapter_by_file(position.file) is None:
            self.show_error("Can't restore position: file unknown.")
            return

        count=0
        for idx, line in enumerate(self.lines):
            count += width.width(line)
            if count >= position.character:
                self.y = idx
                return
        self.show_error("Can't restore mark: character not found.")

    def save_marker(self):
        marker = self.getkey()
        self.position[marker] = self.get_position()

    def goto_marker(self):
        marker = self.getkey()
        position = self.position.get(marker)
        if position:
            self.save_movement_marker()
            self.restore_position(position)

    def open_location(self):
        if not self.prefix:
            self.show_error('No prefix entered')
            return

        try:
            index = self.prefix - 1
            location = self.locations[index]
        except IndexError:
            self.show_error('Illegal index ' + str(self.prefix))
            return

        location = urllib.parse.unquote(location)
        url = urllib.parse.urlparse(location)

        if url.scheme != '':
            self.call_xdg_open(location)
            return

        if self.load_chapter_by_file(url.path) is not None:
            return

        with tempfile.TemporaryDirectory() as dir:
            file = self.epub.zip.extract(location, path=dir)
            self.call_xdg_open(file)

    def load_chapter_by_file(self,file):
        if (index := self.find_chapter(file)) is not None:
            self.load_chapter(index)
            return True

    def load_chapter(self, num=0):
        if num < 0:
            num = 0
        if num >= len(self.chapters) - 1:
            num = len(self.chapters) - 1

        self.y = 0
        self.chapter_index = num
        self.chapter = self.chapters[num]
        self.render_pad()

    def call_xdg_open(self, arg):
        try:
            subprocess.check_call(['xdg-open', arg])
        except subprocess.CalledProcessError as proc:
            rc = str(proc.returncode)
            self.show_error('xdg-open returned non-zero exit status ' + rc)
        except FileNotFoundError as proc:
            self.show_error('Error calling xdg-open: ' + proc.args[1])

    def goto_toc(self):
        if index := self.find_chapter(self.epub.find_toc()):
            self.load_chapter(index)
        else:
            self.show_error('No table of content found')

    def show_help(self):
        lines = []
        for key in self.keys:
            function_name = self.keys[key]
            if key == '\n':
                key = 'RETURN'
            elif key == ' ':
                key = 'SPACE'
            lines.append('{:20} {}'.format(key,function_name))
        TextPager(self.stdscr, lines, title='Help').update()

    def find_chapter(self,file):
        for index,chapter in enumerate(self.chapters):
            if chapter.file == file:
                return index

    def load_start_chapter(self):
        start_chapter = 0
        if index := self.find_chapter(self.epub.bodymatter):
            start_chapter = index
        self.load_chapter(start_chapter)

    def prev_page(self):
        if super().prev_page() is False:
            self.prev_chapter()
            self.goto_end()

    def next_page(self):
        if super().next_page() is False:
            self.next_chapter()

    def render_chapter(self, chapter):
        rendered = self.render_cache.get(chapter.file)
        if rendered is not None:
            return rendered

        renderer = Renderer(self.width, dic=self.dic)
        lines, ids, locations = renderer.render(chapter.source)
        rendered = RenderedChapter(lines, ids, locations)

        ## replace relative with absolute links
        basedir = posixpath.dirname(chapter.file)
        if basedir:
            basedir += '/'
        for index,location in enumerate(rendered.locations):
            url = urllib.parse.urlparse(location)
            if url.scheme == '':
                location = posixpath.normpath(basedir + location)
            rendered.locations[index] = location

        self.render_cache[chapter.file] = rendered
        return rendered

    def set_with(self):
        ## invalidate render_cache if width is changed
        self.render_cache = {}
        super().set_width()

    def get_lines(self):
        chapter = self.chapter
        rendered = self.render_chapter(chapter)
        self.locations = rendered.locations
        return rendered.lines

    def next_chapter(self):
        old = self.chapter_index
        self.save_movement_marker()
        self.load_chapter( self.chapter_index + 1 )
        if old == self.chapter_index:
            self.show_msg('No more chapters.')

    def prev_chapter(self):
        old = self.chapter_index
        self.save_movement_marker()
        self.load_chapter( self.chapter_index - 1 )
        if old == self.chapter_index:
            self.show_msg('Already at first chapter.')

    def exit(self):
        if self.dbfile:
            self.save_state()
        return super().exit()

    def save_state(self):
        position = self.get_position()
        hash = self.epub.hash()
        with sqlite3.connect(self.dbfile) as con:
            con.execute("""
                CREATE TABLE IF NOT EXISTS states (
                    hash      TEXT NOT NULL PRIMARY KEY,
                    filename  TEXT,
                    chapter   TEXT,
                    position  INTEGER,
                    last_read REAL
                )
            """)
            con.execute('PRAGMA user_version = 2;')
            con.execute('INSERT OR REPLACE INTO states VALUES (?,?,?,?,?)',
                (hash, os.path.abspath(self.epub.filename),
                    position.file, position.character, time.time()))

    def load_state(self):
        hash = self.epub.hash()
        with sqlite3.connect(self.dbfile) as con:
            con.row_factory = sqlite3.Row
            cur = con.execute('SELECT * FROM states WHERE hash = ?', (hash,))
            result = cur.fetchone()
            if result:
                result = dict(result)
                return Position(result['chapter'], result['position'])


class Position():
    def __init__(self, file, character):
        self.file = file
        self.character = character

class RenderedChapter():
    def __init__(self, lines, ids, locations):
        self.lines = lines
        self.ids = ids
        self.locations = locations
