# NAME

termpub - Epubreader for the terminal

# SYNOPSIS

termpub \[OPTIONS\] _file_

# DESCRIPTION

termpub aims to be a full featured epub reader for the terminal. It
supports amongst other things the following features:

- display current page according to epub3 page list
- skiping front matter
- jumping to table of contents
- displaying images with an external viewer
- following interal and external urls
- saving and restoring your last reading position

Many text movement commands are compatible with _less(1)_.

The text can be hyphenated if pyphen are installed.

This project was rewritten from perl to python. Your reading state is no
longer saved in the epub document, but in a local sqlite file. You can
find the last version of the perl code under the git branch `perl`.

# OPTIONS

- --hyphenate

    Use pyphen to hyphenate the text. Defaults to false.

- --language LANGUAGE\_TAG

    Set the language used for hyphenation. Defaults to the books language or
    'en_US' if not specified.

- --width WIDTH

    Set screen width. Defaults to 80.

- --dump

    Print rendered book to stdout

# KEY BINDINGS

Some commands may be preceded by a decimal number, called N in the
descriptions below.

- h

    Display help screen.

- \]

    Go to the next chapter.

- \[

    Go to the previous chapter.

- \{

    Go to the first chapter.

- \}

    Go to the last chapter.

- t

    Open a pager with the table of content.

- m

    Followed by any lowercase letter, marks the current position with
    that letter.

- '

    Followed by any lowercase letter, returns to the position which
    was previously marked with that letter. Followed by another single
    quote, returns to the position at which the last "large" movement
    command was executed.

- |

    Set width to N.

- %

    Go to a line N percent into the chapter.

- g

    Go to line N of the chapter, default to line 1 (beginning of
    chapter).

- G

    Go to line N of the chapter, default to the end of the chapter.

- o

    Open link N. _termpub_ calls _xdg-open_ with the url as first
    argument if the link references an external ressource.

- C-l

    Redraw scren.

- C-g

    Cancel numeric prefix _num_ argument.

- DOWN, j, RETURN

    Scroll one line down.

- UP, k

    Scroll one line up.

- ESC-), RIGHT

    Scroll horizontally right N characters, default half the screen
    width. If a number N is specified, it becomes the default for
    future RIGHT and LEFT commands.

- ESC-(, LEFT

    Scroll horizontally left N characters, default half the screen
    width. If a number N is specified, it becomes the default for future
    RIGHT and LEFT commands.

- PAGE_DOWN, SPACE

    Scroll forward one window.

- PAGE_UP, BACKSPACE

    Scroll backward one window.

- HOME

    Go to the beginning of the current chapter.

- END

    Go to the ned of the current chapter.

- q

    Exits _termpub_.

- \/

    Search forward for lines containing the pattern.

- ?

    Search backward for lines containing the pattern.

- n

    Repeat previous search.

- N

    Repeat previous search, but in the reverse direction.

- ESC-u

    Undo search highlighting. If highlighting is already off because of
    a previous ESC-u command, turn highlighting back on.

- !

    Asks for an external Unix command and executes it in a subshell.

- \\

    Show chapter source.

# CONFIGURATION FILE

When termpub is invoked, it will attempt to read a configuration file at
$XDG\_CONFIG\_HOME/termpub/termpubrc. The following example shows some
defaults:

    set hyphenation off
    set language en_US
    set widht 80
    set status_left {title}
    set status_right "{chapter_counter} {percent}"
    map [ prev_chapter
    map ] next_chapter
    map ^L redraw

# INSTALLATION

The project can be installed with `setup.py` and depends on no external
libraries. Only python 3.6 or later is needed.

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
