import termpub.width as width
import curses
import curses.ascii
import itertools
import shlex
import unicodedata
import termpub.graphemebuffer

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

def completion_iterator(line, completion_function):
    lex = shlex.shlex(line)
    tokens = []
    while True:
        try:
            token = lex.get_token()
            if not token:
                if line.endswith(' '):
                    tokens.append('')
                break
            tokens.append(token)
        except ValueError:
            tokens.append(lex.token)
            break

    if not tokens:
        tokens = ['']

    possible_completions = completion_function(tokens)
    if possible_completions is None:
        possible_completions = []
    possible_completions.append(tokens[-1])
    return itertools.cycle(possible_completions), tokens[-1]

def readline( window, prompt=':', y=0, x=0, completion_function=None):

    max_y, max_x = window.getmaxyx()

    iter=None

    ## TODO len() is wrong for non-ascii characters;
    ## to compute display length, just insert it into a pad and
    ## check how much the cursor moved?
    left_pad  = width.width(prompt);

    right_pad = 1 # for cursor

    if left_pad + right_pad >= max_x:
        raise Exception('Window too small for readline().')

    buffer = termpub.graphemebuffer.Buffer()

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

        elif c == "^I":
            if not iter and completion_function:
                line = ''.join(buffer.graphemes[:buffer.index])
                iter, token = completion_iterator(line, completion_function)
                start = buffer.index - width.width(token)
                end = buffer.index

            if iter:
                buffer.replace(start, end, next(iter))
                end = buffer.index

        elif printable is True:
            buffer.add(c)

        if c != "^I" and iter:
            iter = None

    window.move( max_y - 1, 0 );
    window.clrtoeol()
    window.refresh()
    if buffer:
        return buffer.to_string()
