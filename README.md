[![Build Status](https://travis-ci.org/mdom/termpub.svg?branch=master)](https://travis-ci.org/mdom/termpub) [![Coverage Status](https://img.shields.io/coveralls/mdom/termpub/master.svg?style=flat)](https://coveralls.io/r/mdom/termpub?branch=master)
# NAME

App::termpub - Epubreader for the terminal

# SYNOPSIS

termpub _file_

# DESCRIPTION

termpub is a _terminal_ viewer for epubs.

At startup termpub displays the first chapter with real content if
possible. It will save your reading position and restore it.

# KEY BINDINGS

- h, ?

    Display help screen.

- n

    Go to the next chapter.

- p

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

- KEY\_DOWN, j

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

- <,>

    Go back or forward in the chapter history.

- q

    Quit.

# INSTALLATION

If you have cpanminus installed, you can simply install this program
by calling

    $ cpanm .

Otherwise you can build a standalone script with

    $ ./build-standalone

and copy the generated script _termpub_ somewhere in your path. In this
case you need to installed the dependencies yourself. Termpub depends
on the perl modules Mojolicious, Curses and Archive::Zip. On Debian the
following command will install these packages.

    $ apt-get install libmojolicious-perl libcurses-perl libarchive-zip-perl

# COPYRIGHT AND LICENSE 

Copyright 2019 Mario Domgoergen `<mario@domgoergen.com>` 

This program is free software: you can redistribute it and/or modify 
it under the terms of the GNU General Public License as published by 
the Free Software Foundation, either version 3 of the License, or 
(at your option) any later version. 

This program is distributed in the hope that it will be useful, 
but WITHOUT ANY WARRANTY; without even the implied warranty of 
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
GNU General Public License for more details. 

You should have received a copy of the GNU General Public License 
along with this program.  If not, see &lt;http://www.gnu.org/licenses/>. 
