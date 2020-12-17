import curses
import subprocess
import sys

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

def exec_wait(arg, shell=False):
    try:
        curses.endwin()
        subprocess.check_call(arg, shell=shell)
    except subprocess.CalledProcessError as proc:
        rc = str(proc.returncode)
        print( 'process returned non-zero exit status ' + rc,
            file=sys.stderr)
    except FileNotFoundError as proc:
        print('Error calling process: ' + proc.args[1], file=sys.stderr)
    finally:
        sys.stderr.write('Press any key to continue...')
        sys.stderr.flush()
        waitforkey()
        sys.stderr.write('\n')

def xdg_open(arg):
    exec_wait(['xdg-open', arg])
