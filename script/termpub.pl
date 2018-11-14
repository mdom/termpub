#!/usr/bin/perl

use strict;
use warnings;
use Archive::Zip qw(:ERROR_CODES);
use Mojo::DOM;
use Mojo::Util qw(decode encode html_unescape);
use Curses;
use POSIX qw(ceil);

Archive::Zip::setErrorHandler( sub { } );

my @epubs = @ARGV;

my @books;

for my $epub (@epubs) {
    my $archive = eval { Archive::Zip->new };
    if ( eval { $archive->read($epub) } != AZ_OK ) {
        warn "Can't read $epub\n";
        next;
    }
    my $mimetype = $archive->contents('mimetype');
    $mimetype =~ s/[\r\n]+//;
    if ( !$mimetype ) {
        warn "Missing mimetype for $epub: skipping\n";
        next;
    }
    if ( $mimetype ne 'application/epub+zip' ) {
        warn "foo foo Unknown mimetype $mimetype for $epub: skipping\n";
        next;
    }

    my $container     = $archive->contents('META-INF/container.xml');
    my $container_dom = Mojo::DOM->new($container);
    my $root_file = $container_dom->at('rootfiles rootfile')->attr("full-path");

    if ( !$root_file ) {
        warn "No root file defined for $epub\n";
        next;
    }

    my $root = Mojo::Util::decode 'UTF-8', $archive->contents($root_file);
    if ( !$root ) {
        warn "Missing root file $root_file for $epub\n";
        next;
    }
    my $root_dom = Mojo::DOM->new($root);
    my $creator = eval { $root_dom->at('metadata')->at('dc\:creator')->content }
      || 'Unknown';
    my $title =
      eval { $root_dom->at('metadata')->at('dc\:title')->content } || 'Unknown';

    push @books, encode 'UTF-8', html_unescape "$creator - $title";
}

initscr;
noecho;
cbreak;
keypad(1);
curs_set(0);

scroll_window(@books);

END {
    endwin;
}

sub scroll_window {
    my @lines = @_;
    my ( $rows, $columns );
    getmaxyx( stdscr, $rows, $columns );
    my $len      = @lines;
    my $position = 0;
    my $page     = 0;
    my $max_page = ceil( @lines / $rows ) - 1;

	my $changed_page = 1;
	my @current_lines;
	my $old_page = -1;
	my $old_position = $position;

    while (1) {
		if ($old_page != $page ) {
			@current_lines = @lines[ ($page * $rows) .. ($page == $max_page ? $#lines : ($page*$rows+$rows-1))  ];
			$changed_page = 0;
			clear;
			move( 0, 0 );
			addstring(join("\n",@current_lines));
			$old_page = $page;
		}

		if ( $old_position != $position ) {
			move ( $old_position, 0 );
			clrtoeol;
			addstring($current_lines[$old_position]."\n");
			$old_position = $position;
		}

		move($position,0);
		clrtoeol;
		attron(A_REVERSE);
		addstring($current_lines[$position]."\n");
		attroff(A_REVERSE);

        refresh;

        my $c = getch;
        if ( $c == KEY_NPAGE ) {
            if ( $page < $max_page ) {
                $position = 0;
                $page++;
            }
        }
        elsif ( $c == KEY_PPAGE ) {
            if ( $page > 0 ) {
                $position = 0;
                $page--;
            }
        }
		elsif ( $c == KEY_DOWN ) {
			if ( $position < @current_lines - 1 ) {
				$position++
			}
			else {
				if ( $page != $max_page ) {
					$position = 0;
					$page++;
				}
			}
		}
		elsif ( $c == KEY_UP ) {
			if ( $position != 0 ) {
				$position--;
			}
			else {
				if ( $page != 0 ) {
					$position = $rows -1;
					$page--;
				}
			}
		}
        elsif ( $c eq 'q' ) {
            exit(0);
        }
    }

    return;
}
