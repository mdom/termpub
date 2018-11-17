package App::termpub::BookViewer;
use Mojo::Base -base;
use Mojo::Util qw(decode encode html_unescape dumper);
use Curses;
use App::termpub::Renderer;

has renderer => sub { App::termpub::Renderer->new };
has 'epub';
has chapters => sub { shift->epub->chapters };

has chapter => 0;
has line    => 0;
has 'rows';
has 'pad';
has 'max_lines';

has win => sub {
    newwin( 0, 0, 0, 0 );
};

sub next_line {
    my $self = shift;
	if ( $self->line + 1 <= $self->max_lines ) {
		$self->line( $self->line + 1 );
		$self->update_screen;
	}
}

sub prev_line {
    my $self = shift;
    if ( $self->line != 0 ) {
        $self->line( $self->line - 1 );
		$self->update_screen;
    }
}

sub next_page {
    my $self = shift;
    if ( $self->line + $self->rows <= $self->max_lines ) {
        $self->line( $self->line + $self->rows );
		$self->update_screen;
    }
    else {
        $self->next_chapter;
    }
}

sub prev_page {
    my $self = shift;
    if ( $self->line == 0 && $self->chapter - 1 >= 0 ) {
        $self->prev_chapter;
    }
    else {
        if ( $self->line - $self->rows > 0 ) {
            $self->line( $self->line - $self->rows );
        }
        else {
            $self->line(0);
        }
        $self->update_screen;
    }
}

sub update_screen {
    my $self = shift;
	$self->pad->prefresh( $self->line, 0, 0, 0, $self->rows -1, 80 );
}

sub run {
    my $self      = shift;
    my $root_file = Mojo::File->new( $self->epub->root_file );

    my ( $rows, $columns );
    $self->win->getmaxyx( $rows, $columns );
    $self->rows($rows);

    $self->win->scrollok(1);

    $self->set_chapter(0);
    $self->update_screen;

    my %keys = (
        ::KEY_DOWN      => 'next_line',
        ::KEY_UP        => 'prev_line',
        " "             => 'next_page',
        ::KEY_NPAGE     => 'next_page',
        ::KEY_PPAGE     => 'prev_page',
        ::KEY_BACKSPACE => 'prev_page',
        n               => 'next_chapter',
        p               => 'prev_chapter',
        q               => 'quit',
    );

    while (1) {
        my $c      = getchar;
        my $method = $keys{$c};
        next           if !$method;
        return         if $method eq 'quit';
        $self->$method if $method;
    }
    $self->win->getch;
    $self->win->refresh;
}

sub set_chapter {
    my ( $self, $num ) = @_;
    $self->chapter($num);
    $self->line(0);
    $self->render_pad;
	return $self->pad;
}

sub next_chapter {
    my $self = shift;
    while (1) {
        if ( $self->chapters->[ $self->chapter + 1 ] ) {
            if ( $self->set_chapter( $self->chapter + 1 ) ) {
                $self->update_screen;
                return 1;
            }
            else {
                next;
            }
        }
        else {
            return;
        }
    }
    return;
}

sub prev_chapter {
    my $self = shift;
    while (1) {
        if ( $self->chapter > 0 ) {
            if ( $self->set_chapter( $self->chapter - 1 ) ) {
                $self->update_screen;
                return 1;
            }
            next;
        }
        else {
            return;
        }
    }
    return;
}

sub render_pad {
    my $self = shift;
    my ($pad,$max_lines) = $self->renderer->render(
        decode( 'UTF-8', $self->chapters->[ $self->chapter ]->content ) );
	$self->pad( $pad );
	$self->max_lines( $max_lines );
	return;
}

1;
