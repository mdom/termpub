[![Build Status](https://travis-ci.org/mdom/termpub.svg?branch=master)](https://travis-ci.org/mdom/termpub) [![Coverage Status](https://img.shields.io/coveralls/mdom/termpub/master.svg?style=flat)](https://coveralls.io/r/mdom/termpub?branch=master)
# NAME

App::termpub - read epubs in the terminal

# SYNOPSIS

termpub _file_...

# DESCRIPTION

termpub is a _terminal_ viewer for epubs.

# KEY BINDINGS

- n

    Go to the next chapter.

- p

    Go to the previos chapter.

- KEY\_DOWN, SPACE

    Scroll down.

- KEY\_UP

    Scroll up.

- q

    Quit.

# INSTALLATION

If you have cpanminus installed, you can simply install this program
by calling

    $ cpanm .

Otherwise you can bundle all dependencies with

    $ ./build-standalone

and copy the generated script _termpub_ somewhere in your path. In this
case you need to installed the dependencies yourself. Termpub depends
on the perl modules Mojolicious, Curses and Archive::Zip. On a debian
system the following command will install these packages.

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

# POD ERRORS

Hey! **The above document had some coding errors, which are explained below:**

- Around line 200:

    '=end' without a target?
