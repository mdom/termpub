# NAME

termpub - Epubreader for the terminal

# SYNOPSIS

termpub \[OPTIONS\] _file_

# DESCRIPTION

termpub aims to be a full featured epub reader for the terminal.
It supports internal and external links, skips the front matter and
will display images with an external viewer. Your reading position
will be saved and restored.

Many text movement commands are compatible with _less(1)_.

The text can be hyphenated if pyphen are installed.

This project was rewritten from perl to python. The location and format
of the configuration file has changed. Your reading state is no longer
saved in the epub document, but in a local sqlite file. You can find the
last version of the perl code under the git branch `perl`.

# OPTIONS

- --hyphenate

    Use pyphen to hyphenate the text. Defaults to false.

- --language LANGUAGE\_TAG

    Set the language used for hyphenation. Defaults to the books language or
    'en_US' if not specified.

- --width WIDTH

    Set screen width. Defaults to 80.

# KEY BINDINGS

- h

    Display help screen.

- \>

    Go to the next chapter.

- \<

    Go to the previous chapter.

- t

    Jump to the table of contents.

- m

    Followed by any lowercase letter, marks the current position with that
    letter.

- '

    Followed by any lowercase letter, returns to the position which was
    previously marked with that letter. Followed by another single quote,
    returns to the position at which the last "large" movement command was
    executed.

- \[num\] |

    Set pager width to _num_.

- \[num\] %

    Go to a line N percent into the chapter.

- \[num\] g

    Go to line _num_ in the chapter, defaults to 1.

- \[num\] G

    Go to line _num_ in the chapter, default to the end of the chapter.

- \[num\] o

    Open link _num_. _termpub_ calls _xdg-open_ with the url as first
    argument if the link references an external ressource.

- C-g

    Cancel numeric prefix _num_ argument.

- KEY\_DOWN, j, RETURN

    Scroll one line down.

- KEY\_UP, k

    Scroll one line up.

- KEY\_NPAGE, SPACE

    Scroll forward one window.

- KEY\_PPAGE, KEY\_BACKSPACE

    Scroll backward one window.

- KEY\_HOME

    Go to the beginning of the current chapter.

- KEY\_END

    Go to the ned of the current chapter.

- q

    Quit.

- \/

    Search forward for lines containing the pattern.

- n

    Repeat previous search.

- N

    Repeat previous search, but in the reverse direction.

- ESC-u

    Undo search highlighting. If highlighting is already off because of
    a previous ESC-u command, turn highlighting back on.

# CONFIGURATION FILE

When termpub is invoked, it will attempt to read a configuration file at
$XDG\_CONFIG\_HOME/termpub/config.ini that looks like that:

    [termpub]
    hyphenate=no
    language=en_US
    widht=80

# INSTALLATION

The project can be installed with `setup.py`:

    python setup.py install [--user]

# BUGS AND LIMITATIONS

As mentioned, this is a fresh rewrite, so there are probably a lot
of bugs hidden. Sorry for any inconvenience!

# COPYRIGHT AND LICENSE 

Copyright 2020 Mario Domgoergen `<mario@domgoergen.com>` 

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see \<https://www.gnu.org/licenses/>.
