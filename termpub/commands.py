import shlex

class CommandException(Exception):
    def __init__(self, msg):
        self.msg = msg

def parse_command(line):
    command, *args = shlex.split(line, comments=True)
    if command not in ('map', 'set'):
        raise CommandException(f'Unknown command "{command}"')
    if len(args) != 2:
        raise CommandException(f'Wrong number of arguments: {line}'.rstrip())
    if args[1] in ('1', 'true', 'on'):
        args[1] = True
    elif args[1] in ('0', 'false', 'off'):
        args[1] = False
    return command, *args
