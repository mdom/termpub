import curses
import curses.ascii
import re
from termpub.width import width
from termpub.readline import readline, ResizeEvent
from termpub.renderer import Renderer
from termpub.commands import parse_command, CommandException
from termpub.exec import exec_wait

class Pager():

    def __init__(self,stdscr,title=''):
        self.max_y, self.max_x = stdscr.getmaxyx()

        ## Make space for a status line and a command line
        self.max_y -= 2

        self.stdscr = stdscr
        self.y = 0
        self.x = 0
        self.prefix = ''
        self.message = ''

        self.lines = []

        self.exit_functions = ['exit']

        self.horizontal_increment = int(self.max_x / 2)

        self.pattern = ''
        self.highlight = 0
        self.search_direction = 'forward'

        self.title = title
        self.status_left = '-{title}'
        self.status_right = '{percent:->4}--'

        self.position = {}

        self.width = 80
        if self.max_x < self.width:
            self.width = self.max_x

        try:
            curses.curs_set(0)
        except curses.error:
            pass

    def scroll_left(self):
        """Scroll horizontally left N characters, default half the screen"""
        if self.prefix:
            self.horizontal_increment = self.prefix
        self.x -= self.horizontal_increment
        if self.x < 0:
            self.x = 0

    def scroll_right(self):
        """Scroll horizontally right N characters, default half the screen"""
        if self.prefix:
            self.horizontal_increment = self.prefix
        self.x += self.horizontal_increment
        if self.max_x + self.x > self.max_line_length:
            self.x = self.max_line_length - self.max_x

    def set_width(self, width=None):
        if width:
            self.width = width
        elif self.prefix:
            self.width = self.prefix
        self.render_pad()

    def resize(self):
        self.max_y, self.max_x = self.stdscr.getmaxyx()
        self.max_y -= 2
        self.max_x -= 1
        if self.max_x < self.width:
            self.width = self.max_x
        self.render_pad()

    def show_msg(self,msg):
        self.message = msg

    def show_error(self,msg):
        self.message = msg
        curses.beep()

    def update_status_data(self, data=None):
        if data is None:
            data = {}
        last_line = self.y + self.max_y
        if last_line > len(self.lines):
            last_line = len(self.lines)
        percent = int( last_line * 100 / len(self.lines))
        data['percent'] = str(percent) + '%'
        data['title_len'] = width(self.title)
        data['title'] = self.title
        return data

    def draw_status_line(self):
        data = self.update_status_data()

        status_left = self.status_left.format(**data, remaining=0)
        status_right = self.status_right.format(**data, remaining=0)

        width_status_left = width(status_left)
        width_status_right = width(status_right)

        self.stdscr.addstr(self.max_y, 0, self.max_x * '-')
        self.stdscr.addstr(self.max_y, 0, status_left)
        self.stdscr.addstr(
            self.max_y, self.max_x - width_status_right, status_right)
        self.stdscr.chgat( self.max_y, 0, -1, curses.A_STANDOUT );

    def redraw(self):
        """Redraw screen"""
        self.stdscr.clear()

    def update(self):

        self.render_pad()

        self.stdscr.keypad(True)

        redraw = 1

        ## TODO redraw only if something like y or the pad changed
        while True:

            self.draw_status_line()

            if self.message:
                self.stdscr.addstr(self.max_y + 1, 0, self.message)
                self.message = ''
            else:
                self.stdscr.move(self.max_y + 1, 0)
            self.stdscr.clrtoeol()

            if redraw:
                self.stdscr.refresh()
                self.pad.refresh(self.y,self.x,0,0,self.max_y-1,self.max_x-1)
                remaining_lines = len(self.lines) - self.y
                if remaining_lines < self.max_y:
                    win = curses.newwin(
                        self.max_y - remaining_lines,
                        self.max_x,
                        len(self.lines) - self.y,
                        0
                    )
                    win.clear()
                    win.refresh()
                redraw=1

            key = self.getkey()

            if re.match(r'^\d$', key):
                self.prefix += key
                redraw=0
                continue
            if key in self.keys:
                if self.prefix:
                    self.prefix = int(self.prefix)
                method_name = self.keys[key]
                method = getattr( self, method_name )
                rc = method()
                if method_name in self.exit_functions:
                    self.stdscr.erase()
                    return rc
            else:
                self.show_error(f"Key {key} is not bound.  Press 'h' for help.")
            self.prefix = ''
            redraw=1

    key_translations = {
        '\n': 'RETURN',
        '	': 'TAB',
        ' ': 'SPACE',
        curses.KEY_NPAGE: 'PAGE_DOWN',
        curses.KEY_PPAGE: 'PAGE_UP',
        curses.KEY_UP: 'UP',
        curses.KEY_DOWN: 'DOWN',
        curses.KEY_LEFT: 'LEFT',
        curses.KEY_RIGHT: 'RIGHT',
        curses.KEY_HOME: 'HOME',
        curses.KEY_END: 'END',
        curses.KEY_BACKSPACE: 'BACKSPACE',

    }

    def getkey(self):
        ## Wrap getkey in try/catch to handle "no input" crash on KEY_RESIZE
        ## see https://bugs.python.org/issue893250
        while True:
            try:
                c = self.stdscr.get_wch()
                if c in self.key_translations:
                    return self.key_translations[c]
                if type(c) is str:
                    if c == '\x1b':
                        self.pad.nodelay(True)
                        n = self.pad.getch()
                        if n == -1:
                            return 'ESC'
                        else:
                            return 'ESC-' + curses.keyname(n).decode()
                        self.pad.nodelay(False)
                    elif curses.ascii.iscntrl(c):
                        keyname = curses.ascii.unctrl(c)
                        if keyname.startswith('^'):
                            return 'CTRL-' + keyname[1:]
                        else:
                            return keyname
                    else:
                        return c
                else:
                    return curses.keyname(c).decode()
            except curses.error:
                continue

    def save_movement_marker(self):
        pass

    def next_line(self, n=1):
        """Scroll forward N lines, default 1."""
        if self.prefix:
            n = self.prefix
        if self.y + n  < len(self.lines):
            self.y += n

    def prev_line(self, n=1):
        """Scroll backward N lines, default 1."""
        if self.prefix:
            n = self.prefix
        if self.y - n >= 0:
            self.y -= n

    def next_page(self):
        """ Display next page.
        Returns True if there's a next page."""

        if self.y + self.max_y  < len(self.lines):
            self.save_movement_marker()
            self.y += self.max_y
            return True
        return False

    def prev_page(self):
        """ Display previous page.
        Returns True if there's a previous page."""
        if self.y == 0:
            return False
        self.save_movement_marker()
        self.y -= self.max_y
        if self.y < 0:
            self.y = 0
        return True

    def goto_end(self):
        """Go to line N in the file, default to the end of the chapter"""
        self.goto_line(len(self.lines) - self.max_y)

    def goto_line(self, default=0):
        """Go to line N in the file, default 1"""
        self.save_movement_marker()
        if self.prefix:
            self.y = self.prefix - 1
        else:
            self.y = default

        if self.y > len(self.lines):
            self.jump_to_last_page()
        if self.y < 0:
            self.y = 0

    def jump_to_first_page(self):
        """Go to the start of the chapter"""
        self.save_movement_marker()
        self.y = 0

    def jump_to_last_page(self):
        """Go to the end of the chapter"""
        self.save_movement_marker()
        self.y = len(self.lines) - self.max_y

    def exit(self):
        pass

    keys = {
        'DOWN':           'next_line',
        'RETURN':         'next_line',
        'j':              'next_line',
        'UP':             'prev_line',
        'LEFT':           'scroll_left',
        'ESC-(':          'scroll_left',
        'RIGHT':          'scroll_right',
        'ESC-)':          'scroll_right',
        'k':              'prev_line',
        'q':              'exit',
        'g':              'goto_line',
        'G':              'goto_end',
        'PAGE_DOWN':      'next_page',
        'SPACE':          'next_page',
        'PAGE_UP':        'prev_page',
        'END':            'jump_to_last_page',
        'HOME':           'jump_to_first_page',
        'BACKSPACE':      'prev_page',
        'KEY_RESIZE':     'resize',
        'CTRL-L':         'redraw',
        'CTRL-G':         'cancel_prefix',
        '|':              'set_width',
        '%':              'goto_percent',
        '/':              'search_forward',
        '?':              'search_backward',
        'ESC-u':          'toggle_highlighting',
        'n':              'repeat_previous_search',
        'N':              'reverse_previous_search',
        ':':              'eval_command',
        '!':              'shell_escape',
    }

    def shell_escape(self):
        """Invoke a command in a subshell"""
        try:
            curses.curs_set(1)
            line = readline(self.stdscr, prompt='Shell command: ')
            exec_wait(line, shell=True)
        except ResizeEvent:
            self.resize()
        finally:
            curses.curs_set(0)

    def eval_command(self):
        """Enter a termpubrc command"""
        try:
            curses.curs_set(1)
            line = readline(self.stdscr, prompt=':')
        except ResizeEvent:
            self.resize()
        finally:
            curses.curs_set(0)


        if line is None:
            return

        line = line.lstrip()

        if line == '':
            return

        try:
            command, key, value = parse_command(line)
            if command == 'set':
                if key == 'width':
                    self.set_width(width=int(value))
            if command == 'map':
                self.keys[key] = value
        except CommandException as e:
            self.message = e.msg

    def repeat_previous_search(self):
        """Repeat previous search"""
        if self.search_direction == 'forward':
            self.goto_next_match()
        else:
            self.goto_prev_match()

    def reverse_previous_search(self):
        """Repeat previous search, but in the reverse direction"""
        if self.search_direction == 'forward':
            self.goto_prev_match()
        else:
            self.goto_next_match()

    def toggle_highlighting(self):
        """Toggle search highlighting"""
        if self.highlight:
            self.highlight = 0
        else:
            self.highlight = 1
        self.render_pad()

    def search_forward(self):
        """Search forward for pattern"""
        self.search(direction="forward")

    def search_backward(self):
        """Search backward for pattern"""
        self.search(direction="backward", prompt='?')

    def search(self, direction="forward", prompt='/'):
        try:
            curses.curs_set(1)
            pattern = readline(self.stdscr, prompt=prompt)
        except ResizeEvent:
            self.resize()
        finally:
            curses.curs_set(0)

        if pattern:
            self.highlight = 1
            self.pattern = pattern
            self.render_pad()
            self.search_direction = direction
            self.repeat_previous_search()

    def goto_next_match(self):
        """Goto next lines with match.
           Returns True if a match is found, otherwise False."""
        for line in self.matching_lines:
            if line > self.y:
                self.y = line
                return True
        return False

    def goto_prev_match(self):
        """Goto previous lines with match.
           Returns True if a match is found, otherwise False."""
        for line in reversed(self.matching_lines):
            if line < self.y:
                self.y = line
                return True
        return False

    def goto_percent(self):
        """Go to a position N percent into the chapter"""
        self.save_movement_marker()
        if self.prefix:
            line_number = int(self.prefix * len(self.lines)/100)
            self.y = line_number
        else:
            self.y = 0

    def cancel_prefix(self):
        """Cancel current prefix"""
        self.prefix = ''

    def render_pad(self):
        self.stdscr.erase()
        self.lines = self.get_lines()
        if not self.lines:
            self.lines = ['']

        self.max_line_length = 0
        for line in self.lines:
            w = width(line)
            if w > self.max_line_length:
                self.max_line_length = w

        self.pad = curses.newpad(len(self.lines), self.max_line_length + 1)
        for index,line in enumerate(self.lines):
            self.pad.addstr(index,0,line)

        self.matching_lines = []
        if self.pattern and self.highlight:
            for idx, line in enumerate(self.lines):
                for m in re.finditer(self.pattern, line):
                    self.matching_lines.append(idx)
                    self.pad.chgat(
                        idx, m.start(), m.end() - m.start(), curses.A_STANDOUT)

class TextPager(Pager):

    def __init__(self, stdscr, lines, title=''):
        self._lines = lines
        super().__init__(stdscr, title)

    def get_lines(self):
        return self._lines

class HTMLPager(Pager):
    def __init__(self, stdscr, source, title='', base_url=None):
        self._lines, _, self.locations = \
            Renderer(base_url=base_url).render(source)
        super().__init__(stdscr, title)
        self.keys['o'] = 'open_link'
        self.exit_functions.append('open_link')
        self.message = 'q - quit, [num]o - open location'

    def get_lines(self):
        return self._lines

    def open_link(self):
        if not self.prefix:
            self.show_error('No prefix entered')
            return
        try:
            return self.locations[self.prefix - 1]
        except IndexError:
            self.show_error('Illegal index ' + str(self.prefix))
            return
