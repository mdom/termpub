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

    max_display  = max_x - left_pad - right_pad;

    buffer_pos = 0
    buffer = ''

    max_buffer_size = max_x - left_pad - right_pad

    while True:

        if buffer_pos < 0:
            buffer_pos = 0

        buffer_start = 0
        cursor_pos = 0
        correction = 0

        for idx, c in enumerate(buffer[:buffer_pos]):
            if not unicodedata.combining(c):
                cursor_pos += 1
                if cursor_pos % max_display == 0:
                    buffer_start = next_buffer_pos(buffer,idx)
                    correction = cursor_pos

        buffer_end = buffer_start
        visible = 0
        for idx, c in enumerate(buffer[buffer_start:]):
            buffer_end += 1
            if not unicodedata.combining(c):
                visible += 1
                if visible >= max_buffer_size:
                    break

        for idx,c in enumerate(buffer[buffer_end:]):
            if unicodedata.combining(c):
                buffer_end += 1
            else:
                break

        window.addstr( max_y - 1, 0, prompt + buffer[buffer_start:buffer_end])
        window.clrtoeol()

        window.move( max_y - 1, cursor_pos + left_pad - correction )

        c, printable = getkey(window)

        if c == "^G":
            buffer = None
            break

        elif c == '^J':
            break

        elif c == 'KEY_RESIZE':
            raise ResizeEvent()

        elif c == 'KEY_LEFT':
            buffer_pos = prev_buffer_pos(buffer, buffer_pos)

        elif c == 'KEY_RIGHT':
            buffer_pos = next_buffer_pos(buffer, buffer_pos)

        elif c == 'KEY_HOME' or c == '^A':
            buffer_pos = 0

        elif c == '^K':
            buffer = buffer[:buffer_pos]

        elif c == 'KEY_END' or c == '^E':
            buffer_pos = len(buffer)

        elif c == 'KEY_BACKSPACE':
            p = buffer_pos
            buffer_pos = prev_buffer_pos(buffer, buffer_pos)
            buffer = buffer[:buffer_pos] + buffer[p:]

        elif c == "^D":
            p = buffer_pos
            buffer_pos = next_buffer_pos(buffer, buffer_pos)
            buffer = buffer[:p] + buffer[buffer_pos:]

        elif printable is True:
            buffer = buffer[:buffer_pos] + c + buffer[buffer_pos:]
            buffer_pos += 1

    window.move( max_y - 1, 0 );
    window.clrtoeol()
    window.refresh()
    return buffer

def next_buffer_pos(buffer, buffer_pos):
    """Return next non combining character index from buffer_pos in buffer"""
    l = len(buffer)
    while buffer_pos < l:
        buffer_pos += 1
        if buffer_pos < l and unicodedata.combining(buffer[buffer_pos]):
            continue
        break
    return buffer_pos

def prev_buffer_pos(buffer, buffer_pos):
    """Return last non combining character index from buffer_pos in buffer"""
    while True:
        if buffer_pos == 0:
            return buffer_pos
        buffer_pos -= 1
        if unicodedata.combining(buffer[buffer_pos]):
            continue
        else:
            return buffer_pos


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

    def to_string(self):
        return ''.join(self.graphemes)

    def window(self, width):
        offset = int( self.index / width) * width
        return ''.join(self.graphemes[offset:offset+width])
