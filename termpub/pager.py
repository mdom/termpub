import curses
import curses.ascii
import re
import termpub.width as width

class Pager():

    def __init__(self,stdscr,title=''):
        self.max_y, self.max_x = stdscr.getmaxyx()

        ## Make space for a status line and a command line
        self.max_y -= 2

        self.stdscr = stdscr
        self.y = 0
        self.prefix = ''
        self.message = ''

        self.title = title

        self.position = {}

        self.width = 80
        if self.max_x < self.width:
            self.width = self.max_x

        try:
            curses.curs_set(0)
        except curses.error:
            pass

    def set_width(self):
        if self.prefix:
            self.width = self.prefix
            self.render_pad()

    def resize(self):
        self.max_y, self.max_x = self.stdscr.getmaxyx()
        self.max_y -= 2
        self.max_x -= 1
        if self.max_x < self.width:
            self.width = self.max_x
        self.render_pad()

    def current_positions(self):
        self.linesself.y

    def show_msg(self,msg):
        self.message = msg

    def show_error(self,msg):
        self.message = msg
        curses.beep()

    def format_status_line(self):
        data = dict()
        template = '-{title:-<{title_len}}{filler:->{remaining}}{percent:->4}---'
        percent = int( ( self.y + 1 ) * 100 / len(self.lines))
        data['percent'] = str(percent) + '%'
        data['title_len'] = width.width(self.title)
        data['title'] = self.title
        data['filler'] = ''
        data['remaining'] =  self.max_x - width.width(template.format(**data, remaining=0))

        return template.format(**data)

    def draw_status_line(self):
        status = self.format_status_line()
        self.stdscr.addstr(self.max_y, 0, status)
        self.stdscr.chgat( self.max_y, 0, -1, curses.A_STANDOUT );

    def update(self):

        self.render_pad()

        self.stdscr.keypad(True)

        redraw = 1

        #curses.curs_set(1)
        #raise Exception(readline.readline(self.stdscr))
        #curses.curs_set(0)

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
                self.pad.refresh(self.y,0,0,0,self.max_y-1,self.max_x-1)
                remaining_lines = len(self.lines) - self.y
                if remaining_lines < self.max_y:
                    win = curses.newwin( self.max_y - remaining_lines, self.max_x, len(self.lines) - self.y, 0)
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
                method = getattr( self, self.keys[key] )
                if method() is False:
                    break
            else:
                self.show_error("Key is not bound.  Press 'h' for help.")
            self.prefix = ''
            redraw=1


    def getkey(self):
        ## Wrap getkey in try/catch to handle "no input" crash on KEY_RESIZE
        ## see https://bugs.python.org/issue893250
        while True:
            try:
                c = self.stdscr.get_wch()
                if type(c) is str:
                    if c == '\x1b':
                        self.pad.nodelay(True)
                        n = self.pad.getch()
                        if n == -1:
                            return '^]'
                        else:
                            return '^]' + curses.keyname(n).decode()
                        self.pad.nodelay(False)
                    elif curses.ascii.iscntrl(c):
                        return curses.ascii.unctrl(c)
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
        """ Display nage page. Returns True if there's a next page."""
        if self.y + self.max_y  < len(self.lines):
            self.save_movement_marker()
            self.y += self.max_y
            return True
        return False

    def prev_page(self):
        """ Display previous page. Returns True if there's a previous page."""
        if self.y == 0:
            return False
        self.save_movement_marker()
        self.y -= self.max_y
        if self.y < 0:
            self.y = 0
        return True

    def goto_end(self):
        self.goto_line(len(self.lines) - self.max_y)

    def goto_line(self, default=0):
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
        self.save_movement_marker()
        self.y = 0

    def jump_to_last_page(self):
        self.save_movement_marker()
        self.y = len(self.lines) - self.max_y

    def exit(self):
        return False

    keys = {
        'KEY_DOWN':       'next_line',
        'j':              'next_line',
        '\n':             'next_line',
        'KEY_UP':         'prev_line',
        'k':              'prev_line',
        'q':              'exit',
        'g':              'goto_line',
        'G':              'goto_end',
        'KEY_NPAGE':      'next_page',
        ' ':              'next_page',
        'KEY_PPAGE':      'prev_page',
        'KEY_END':        'jump_to_last_page',
        'KEY_HOME':       'jump_to_first_page',
        'KEY_BACKSPACE':  'prev_page',
        'KEY_RESIZE':     'resize',
        '^G':             'cancel_prefix',
        '|':              'set_width',
        '%':              'goto_percent',
    }

    def goto_percent(self):
        self.save_movement_marker()
        if self.prefix:
            line_number = int(self.prefix * len(self.lines)/100)
            self.y = line_number
        else:
            self.y = 0

    def cancel_prefix(self):
        self.prefix = ''

    def render_pad(self):
        self.lines = self.get_lines()
        if not self.lines:
            self.lines = ['']
        self.pad = curses.newpad(len(self.lines), self.max_x)
        for index,line in enumerate(self.lines):
            self.pad.addstr(index,0,line)

class TextPager(Pager):

    def __init__(self, stdscr, lines, title=''):
        self._lines = lines
        super().__init__(stdscr, title)

    def get_lines(self):
        return self._lines



