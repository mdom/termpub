[![Build Status](https://travis-ci.org/mdom/termpub.svg?branch=master)](https://travis-ci.org/mdom/termpub) [![Coverage Status](https://img.shields.io/coveralls/mdom/termpub/master.svg?style=flat)](https://coveralls.io/r/mdom/termpub?branch=master)
# NAME

App::termpub - read epubs in the terminal

# SYNOPSIS

termpub _file_...

# DESCRIPTION

termpub is a _terminal_ viewer for epubs. At startup termpub displays
the first chapter with real content if possible.

# KEY BINDINGS

- h, ?

    Display help screen.

- n

    Go to the next chapter.

- p

    Go to the previous chapter.

- \[num\] g

    Go to line _num_ in the chapter, defaults to 1.

- \[num\] G

    Go to line _num_ in the chapter, default to the end of the chapter.

- C-g

    Cancel _num_ argument for _g_ or _G_.

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
