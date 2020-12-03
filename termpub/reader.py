from termpub.pager import Pager, TextPager
from termpub.renderer import Renderer
import curses
import json
import os
import os.path
import time
import posixpath
import re
import sqlite3
import sys
import subprocess
import tempfile
import termpub.width as width
from xml.dom.minidom import parseString

try:
    # Win32
    from msvcrt import getch as waitforkey
except ImportError:
    # UNIX
    def waitforkey():
        import tty, termios
        fd = sys.stdin.fileno()
        old = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            return sys.stdin.read(1)
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old)

class Reader(Pager):

    def __init__(self, epub, stdscr, *,
        language='en_US',
        width=80,
        hyphenate=False,
        dbfile=None,
        status_left=None,
        status_right=None,
    ):
        super().__init__(stdscr)

        self.epub = epub
        self.chapter = None
        self.chapters = self.epub.chapters
        self.chapter_index = 0
        self.pads = [None] * len(self.chapters)
        self.pad = None
        self.current_line = 0

        if self.epub.author:
            self.title = f"{epub.title} ({epub.author})"
        else:
            self.title = epub.title

        self.dbfile = dbfile

        if self.max_x > width:
            self.width = width

        self.locations = []
        self.render_cache = {}

        if status_left:
            self.status_left = status_left

        if status_right:
            self.status_right = status_right
        else:
            self.status_right = '{current_page}---{chapter_counter}--{percent:->4}--'

        self.dic=None
        if hyphenate:
            lang = epub.language or language
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

        self.keys[']'] = 'next_chapter'
        self.keys['['] = 'prev_chapter'
        self.keys['h'] = 'show_help'
        self.keys['t'] = 'goto_toc'
        self.keys['o'] = 'follow_link'
        self.keys["m"] = 'save_marker'
        self.keys["'"] = 'goto_marker'
        self.keys['\\'] = 'show_source'

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

    def goto_next_match(self):
        if self.pattern and super().goto_next_match() is False:
            for idx, chapter in enumerate(self.chapters):
                if idx > self.chapter_index:
                    rendered = self.render_chapter(chapter)
                    if re.search(self.pattern, ''.join(rendered.lines)):
                        self.load_chapter(idx)
                        super().goto_next_match()
                        break

    def goto_prev_match(self):
        if self.pattern and super().goto_prev_match() is False:
            for idx, chapter in reversed(list(enumerate(self.chapters))):
                if idx < self.chapter_index:
                    rendered = self.render_chapter(chapter)
                    if re.search(self.pattern, ''.join(rendered.lines)):
                        self.load_chapter(idx)
                        self.goto_end()
                        super().goto_prev_match()
                        break

    def goto_marker(self):
        marker = self.getkey()
        position = self.position.get(marker)
        if position:
            self.save_movement_marker()
            self.restore_position(position)

    def follow_link(self):
        if not self.prefix:
            self.show_error('No prefix entered')
            return

        try:
            index = self.prefix - 1
            url = self.locations[index]
        except IndexError:
            self.show_error('Illegal index ' + str(self.prefix))
            return

        self.goto_location(url)

    def goto_location(self, url):
        if url.scheme != '':
            self.call_xdg_open(url.geturl())
            return True

        index = self.find_chapter(url.path)
        if index is not None:
            ## do not remember position on startup
            if self.lines:
                self.save_movement_marker()
            self.load_chapter(index)
            fragment = url.fragment
            if fragment:
                line = self.ids.get(fragment)
                if line:
                    self.y = line
            return True

        with tempfile.TemporaryDirectory() as dir:
            file = self.epub.zip.extract(url.path, path=dir)
            self.call_xdg_open(file)
            return True

    def load_chapter_by_file(self,file):
        index = self.find_chapter(file)
        if index is not None:
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
            curses.endwin()
            subprocess.check_call(['xdg-open', arg])
        except subprocess.CalledProcessError as proc:
            rc = str(proc.returncode)
            print( 'xdg-open returned non-zero exit status ' + rc,
                file=sys.stderr)
        except FileNotFoundError as proc:
            print('Error calling xdg-open: ' + proc.args[1], file=sys.stderr)
        sys.stderr.write('Press any key to continue...')
        sys.stderr.flush()
        waitforkey()
        sys.stderr.write('\n')

    def goto_toc(self):
        url = self.epub.find_toc()
        if url and self.goto_location(url):
            return
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
        if self.epub.bodymatter:
            self.goto_location(self.epub.bodymatter)
        else:
            self.load_chapter(0)

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

        renderer = Renderer(self.width, dic=self.dic, base_url=chapter.file)
        lines, ids, locations = renderer.render(chapter.source)
        rendered = RenderedChapter(lines, ids, locations)

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
        self.ids = rendered.ids
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

    def update_status_data(self):

        data = {
            'author': self.epub.author,
            'chapter_counter': f'{self.chapter_index + 1}/{len(self.chapters)}',
            'current_page': '',
        }

        if self.epub.nav_doc:
            file = self.chapters[self.chapter_index].file
            for url, text in self.epub.nav_doc.page_list.items():
                if url.path == file:
                    line = self.ids[url.fragment]
                    if line > self.y:
                        break
                    data['current_page'] = 'p.' + text

        return super().update_status_data(data)

    def show_source(self):
        source = self.chapters[self.chapter_index].source
        lines = parseString(source).toprettyxml(indent="  ").splitlines()
        TextPager( self.stdscr, lines, title='Source').update()

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
                (hash, os.path.abspath(self.epub.file),
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
