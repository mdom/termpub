package App::termpub;
use Mojo::Base 'App::termpub::Pager';
use Mojo::Util 'decode';
use App::termpub::Renderer;
use Curses;

our $VERSION = '1.00';

has 'epub';
has chapters => sub { shift->epub->chapters };
has chapter => 0;

sub run {
    my $self = shift;

    $self->set_chapter( $self->epub->start_chapter );

    $self->key_bindings->{n} = 'next_chapter';
    $self->key_bindings->{p} = 'prev_chapter';
    $self->key_bindings->{h} = 'help_screen';

    $self->SUPER::run;
}

my %keycodes = (
    Curses::KEY_DOWN      => '<Down>',
    Curses::KEY_UP        => '<Up>',
    ' '                   => '<Space>',
    Curses::KEY_NPAGE     => '<PageDown>',
    Curses::KEY_PPAGE     => '<PageUp>',
    Curses::KEY_BACKSPACE => '<Backspace>',
    Curses::KEY_HOME      => '<Home>',
    Curses::KEY_END       => '<End>',
);

sub help_screen {
    my $self = shift;
    my $pad  = newpad( scalar keys %{ $self->key_bindings }, $self->columns );
    my @keys = sort keys %{ $self->key_bindings };

    my $row    = 0;
    my $length = 0;
    for my $key (@keys) {
        my $str = $keycodes{$key} || $key;
        $length = length($str) if length($str) > $length;
    }

    for my $key (@keys) {
        $pad->addstring( ( $keycodes{$key} || $key ) );
        $pad->addstring(
            $row,
            $length,
            ' = ' . $self->key_bindings->{$key} . "\n"
        );
        $row++;
    }

    App::termpub::Pager->new( pad => $pad )->run;

    $self->update_screen;
}

sub update_screen {
    my $self = shift;

    $self->SUPER::update_screen;

    move( $self->rows, 0 );
    addstring( $self->chapters->[ $self->chapter ]->title );

    my $pos = int( $self->line * 100 / $self->max_lines ) . '%';
    if ( $self->line + $self->rows - 1 >= $self->max_lines ) {
        $pos = "end";
    }
    $pos = "($pos)";
    addstring( '-' x $self->columns );
    move( $self->rows, $self->columns - length($pos) - 2 );
    addstring($pos);

    move( $self->rows, 0 );
    chgat( -1, A_STANDOUT, 0, 0 );
    refresh;
}

sub set_chapter {
    my ( $self, $num ) = @_;
    $self->chapter($num);
    $self->line(0);
    $self->render_pad( $self->chapters->[ $self->chapter ]->content );
    return;
}

sub next_chapter {
    my $self = shift;
    while (1) {
        if ( $self->chapters->[ $self->chapter + 1 ] ) {
            $self->set_chapter( $self->chapter + 1 );
            if ( $self->pad ) {
                $self->update_screen;
                return;
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

sub next_page {
    my $self = shift;
    $self->next_chapter if !$self->SUPER::next_page;
}

sub prev_page {
    my $self = shift;
    $self->prev_chapter if !$self->SUPER::prev_page;
}

sub prev_chapter {
    my $self = shift;
    while (1) {
        if ( $self->chapter > 0 ) {
            $self->set_chapter( $self->chapter - 1 );
            if ( $self->pad ) {
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
    my ( $self, $content ) = @_;
    my ($pad) =
      App::termpub::Renderer->new->render( decode( 'UTF-8', $content ) );
    $self->pad($pad);
    $self->max_lines( $self->get_max_lines );
    return;
}

1;
