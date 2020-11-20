import termpub.width as width
import curses

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

def readline(window, prefix=':', y=0, x=0):

    max_y, max_x = window.getmaxyx()

    ## TODO len() is wrong for non-ascii characters;
    ## to compute display length, just insert it into a pad and
    ## check how much the cursor moved?
    left_pad  = widht.width(prefix);

    right_pad = 1 # for cursor

    if left_pad + right_pad >= max_x:
        raise Exception('Window too small for readline().')

    max_display  = max_x - left_pad - right_pad;

    cursor_position = 0
    buffer = ''
    buffer_offset = 0

    max_buffer_size = max_x - left_pad - right_pad

    while True:

        if cursor_position < 0:
            cursor_position = 0

        buffer_offset = int( cursor_position / max_buffer_size) * max_buffer_size

        window.addstr( max_y - 1, 0, prefix + buffer[buffer_offset:buffer_offset + max_buffer_size])
        window.clrtoeol()

        window.move( max_y - 1, cursor_position + left_pad - buffer_offset)

        c, printable = getkey(window)

        if c == "^G":
            buffer = None
            break

        elif c == '^J':
            break

        elif c == 'KEY_LEFT':
            cursor_position -= 1

        elif c == 'KEY_RIGHT':
            if cursor_position == widht.width(buffer):
                continue
            cursor_position += 1

        elif c == 'KEY_HOME' or c == '^A':
            cursor_position = 0

        elif c == '^K':
            buffer = buffer[:cursor_position]

        elif c == 'KEY_END' or c == '^E':
            cursor_position = widht.width(buffer);

        elif c == 'KEY_BACKSPACE':
            buffer = buffer[:cursor_position - 1] + buffer[cursor_position:]
            cursor_position -= 1

        elif c == "^D":
            buffer = buffer[:cursor_position] + buffer[cursor_position+1:]

        elif printable is True:
            buffer = buffer[:cursor_position] + c + buffer[cursor_position:]
            cursor_position += 1

    window.move( max_y - 1, 0 );
    window.clrtoeol()
    window.refresh()
    return buffer

