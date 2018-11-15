#!/usr/bin/perl

package Epub;
use Mojo::Base -base;
use Mojo::DOM;
use Mojo::Util qw(decode encode html_unescape);
use Archive::Zip qw(:ERROR_CODES);

has 'filename';

has archive => sub {
    my $self    = shift;
	my $filename = $self->filename;
    my $archive = Archive::Zip->new;
    if ( eval { $archive->read($filename) } != AZ_OK ) {
        die "Can't read $filename\n";
    }
    my $mimetype = $archive->contents('mimetype');
    $mimetype =~ s/[\r\n]+//;
    if ( !$mimetype ) {
        die "Missing mimetype for $filename\n";
    }
    if ( $mimetype ne 'application/epub+zip' ) {
        die "Unknown mimetype $mimetype for $filename\n";
    }
    return $archive;
};

has root_file => sub {
	my $self = shift;
    my $filename      = $self->filename;
    my $container     = $self->archive->contents('META-INF/container.xml');
    my $container_dom = Mojo::DOM->new($container);
    my $root_file = $container_dom->at('rootfiles rootfile')->attr("full-path");
    if ( !$root_file ) {
        die "No root file defined for $filename\n";
    }
    return $root_file;
};

has root_dom => sub {
	my $self = shift;
    my $root = Mojo::Util::decode 'UTF-8', $self->archive->contents($self->root_file);
    if ( !$root ) {
        die "Missing root file " . $self->root_file ." for " . $self->filename . "\n";
    }
    return Mojo::DOM->new($root);
};

has creator => sub {
	my $self = shift;
	return html_unescape( eval { $self->root_dom->at('metadata')->at('dc\:creator')->content } || 'Unknown');
};

has title => sub {
	my $self = shift;
	return html_unescape( eval { $self->root_dom->at('metadata')->at('dc\:title')->content } || 'Unknown');
};

package main;

use strict;
use warnings;
use Mojo::DOM;
use Mojo::File;
use Mojo::Util qw(decode encode html_unescape);
use Curses;
use POSIX qw(ceil);
use Text::Wrap;

Archive::Zip::setErrorHandler( sub { } );

my @filenames = @ARGV;

my @epubs;

for my $filename (@filenames) {

	my $epub = eval { Epub->new( filename => $filename ) };

	if ( !$epub ) {
		warn "$@\n";
		next;
	}

    push @epubs, $epub;
}

initscr;
noecho;
cbreak;
keypad(1);
curs_set(0);

my $position = 0;
while (1) {
	my @lines = map { encode 'UTF-8', $_->creator . " - " . $_->title } @epubs;
    my $position = select_line( $position, @lines );
    if ( not defined $position ) {
        last;
    }
    read_book( $epubs[$position] );
}

END {
    endwin;
}

sub read_book {
    my $epub = shift;

	my $root_file = Mojo::File->new( $epub->root_file );

    my @idrefs = $epub->root_dom->find('spine itemref')->map( attr => 'idref' )->each;
    my $chapter_selector = join( ',', map { "manifest item#$_" } @idrefs );
    my @chapter_files =
      $epub->root_dom->find($chapter_selector)
      ->grep( sub { $_->attr('media-type') eq 'application/xhtml+xml' } )
      ->map( attr => 'href' )->map( sub { $root_file->sibling($_)->to_rel } )->each;
	  clear;
	  move(0,0);
    addstring( render_content( decode('UTF-8', $epub->archive->contents( "".$chapter_files[4] )) ));
	refresh;
	getch;
}

sub select_line {
    my ( $position, @lines ) = @_;
    my ( $rows, $columns );
    getmaxyx( stdscr, $rows, $columns );
    my $len      = @lines;
    my $page     = 0;
    my $max_page = ceil( @lines / $rows ) - 1;

    my $changed_page = 1;
    my @current_lines;
    my $old_page     = -1;
    my $old_position = $position;

    while (1) {
        if ( $old_page != $page ) {
            @current_lines =
              @lines[ ( $page * $rows )
              .. (
                  $page == $max_page ? $#lines : ( $page * $rows + $rows - 1 ) )
              ];
            $changed_page = 0;
            clear;
            move( 0, 0 );
            addstring( join( "\n", @current_lines ) );
            $old_page = $page;
        }

        if ( $old_position != $position ) {
            move( $old_position, 0 );
            clrtoeol;
            addstring( $current_lines[$old_position] . "\n" );
            $old_position = $position;
        }

        move( $position, 0 );
        clrtoeol;
        attron(A_REVERSE);
        addstring( $current_lines[$position] . "\n" );
        attroff(A_REVERSE);

        refresh;

        my $c = getchar;
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
                $position++;
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
                    $position = $rows - 1;
                    $page--;
                }
            }
        }
        elsif ( $c eq "\n" ) {
            return $position;
        }
        elsif ( $c eq 'q' ) {
            return;
        }
    }

    return;
}

sub infobox {
    my $text = shift;
    my $win = newwin( 20, 20, 5, 5 );
    border(
        $win,      ACS_VLINE,    ACS_VLINE,    ACS_HLINE,
        ACS_HLINE, ACS_ULCORNER, ACS_URCORNER, ACS_LLCORNER,
        ACS_LRCORNER
    );
    move( $win, 1, 1 );
    addstring( $win, $text );
    refresh($win);
    getch;
    delwin($win);
    touchwin(stdscr);
    refresh;
    return;
}

sub render_content {
    my ($item) = shift;
    return fill( '  ', '  ', render_dom( Mojo::DOM->new( $item ) ) );
}

sub render_dom {
    my $node    = shift;
    my $content = '';
    for ( $node->child_nodes->each ) {
        $content .= render_dom($_);
    }
    if ( $node->type eq 'text' ) {
        $content = $node->content;
        $content =~ s/\.\s\.\s\./.../;
        return '' if $content !~ /\S/;
        return $content;
    }
    elsif ( $node->type eq 'tag' && $node->tag =~ /^h\d+$/
        || is_tag( $node, 'p', 'div' ) )
    {
        return "$content ";
    }
    return $content;
}

sub is_tag {
    my ( $node, @tags ) = @_;
    return
      if $node->type ne 'tag';
    for my $tag (@tags) {
        return 1
          if $node->tag eq $tag;
    }
    return;
}

exit 0;
