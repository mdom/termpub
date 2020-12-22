import termpub.width as width
import curses
import curses.ascii
import unicodedata

class ResizeEvent(Exception):
    pass

def getkey(stdscr):
    while True:
        try:
            c = stdscr.get_wch()
            if type(c) is str:
                if curses.ascii.iscntrl(c):
                    return curses.ascii.unctrl(c), False
                return c, True
            else:
                return curses.keyname(c).decode(), False
        except curses.error:
            continue

def readline(window, prompt=':', y=0, x=0):

    max_y, max_x = window.getmaxyx()

    ## TODO len() is wrong for non-ascii characters;
    ## to compute display length, just insert it into a pad and
    ## check how much the cursor moved?
    left_pad  = width.width(prompt);

    right_pad = 1 # for cursor

    if left_pad + right_pad >= max_x:
        raise Exception('Window too small for readline().')

    buffer = Buffer()

    max_buffer_size = max_x - left_pad - right_pad

    while True:

        slice, index = buffer.slice(max_buffer_size)

        window.addstr(max_y - 1, 0, prompt + slice)
        window.clrtoeol()

        window.move(max_y - 1, index + left_pad)

        c, printable = getkey(window)

        if c == "^G":
            buffer = None
            break

        elif c == '^J':
            break

        elif c == 'KEY_RESIZE':
            raise ResizeEvent()

        elif c == 'KEY_LEFT':
            buffer.move_left()

        elif c == 'KEY_RIGHT':
            buffer.move_right()

        elif c == 'KEY_HOME' or c == '^A':
            buffer.move_to_start()

        elif c == '^K':
            buffer.delete_to_end()

        elif c == 'KEY_END' or c == '^E':
            buffer.move_to_end()

        elif c == 'KEY_BACKSPACE':
            buffer.delete_backward()

        elif c == "^D":
            buffer.delete_forward()

        elif printable is True:
            buffer.add(c)

    window.move( max_y - 1, 0 );
    window.clrtoeol()
    window.refresh()
    if buffer:
        return buffer.to_string()

class Buffer():

    def __init__(self):
        self.graphemes = []
        self.index = 0

    def add(self, string):
        """Add c to string at current index."""
        for c in string:
            if unicodedata.combining(c):
                self.graphemes[self.index - 1] += c
            else:
                self.graphemes.insert(self.index, c)
                self.index += 1

    def move_to_start(self):
        self.index = 0

    def move_to_end(self):
        self.index = len(self.graphemes)

    def move_left(self, n=1):
        if self.index - n >= 0:
            self.index -= n

    def move_right(self, n=1):
        if self.index + n <= len(self.graphemes):
            self.index += n

    def current_grapheme(self):
        return self.graphemes[self.index - 1]

    def delete_forward(self):
        if self.index < len(self.graphemes):
            del self.graphemes[self.index]

    def delete_backward(self):
        if self.index != 0:
            del self.graphemes[self.index - 1]
            self.index -= 1

    def delete_to_end(self):
        del self.graphemes[self.index:]

    def to_string(self):
        return ''.join(self.graphemes)

    def slice(self, width):
        offset = int( self.index / width) * width
        return ''.join(self.graphemes[offset:offset+width]), self.index - offset

    def clear(self):
        self.index = 0
        self.graphemes = []
