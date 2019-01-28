package App::termpub;
use Mojo::Base 'App::termpub::Pager';
use Mojo::Util 'decode';
use Mojo::URL;
use Mojo::File 'tempfile';
use Mojo::JSON 'encode_json', 'decode_json';
use App::termpub::Renderer;
use Curses;

our $VERSION = '1.00';

has 'epub';
has chapters => sub { shift->epub->chapters };
has chapter  => sub { shift->epub->start_chapter };
has 'hrefs';
has history => sub { [ shift->chapter ] };
has history_index => 0;
has 'renderer';

sub run {
    my $self = shift;

    $self->title( $self->chapters->[ $self->chapter ]->title );
    $self->render_pad;

    my $data = $self->epub->read_metadata;

    if ( $data && $data->{position} ) {
        $self->set_chapter( $data->{position}->[0] );
        $self->goto_percent( $data->{position}->[1] );
    }

    $self->key_bindings->{n}                  = 'next_chapter';
    $self->key_bindings->{p}                  = 'prev_chapter';
    $self->key_bindings->{h}                  = 'help_screen';
    $self->key_bindings->{o}                  = 'open_link';
    $self->key_bindings->{'?'}                = 'help_screen';
    $self->key_bindings->{t}                  = 'jump_to_toc';
    $self->key_bindings->{'<'}                = 'history_back';
    $self->key_bindings->{'>'}                = 'history_forward';
    $self->key_bindings->{Curses::KEY_RESIZE} = 'handle_resize';

    $self->SUPER::run;

    $self->epub->save_metadata(
        { version => 1, position => [ $self->chapter, $self->get_percent ] } );
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

sub handle_resize {
    my $self = shift;
    $self->SUPER::handle_resize;
    $self->render_pad;
    $self->update_screen;
}

sub jump_to_toc {
    my $self = shift;
    if ( $self->epub->toc ) {
        $self->set_chapter( $self->epub->toc );
        $self->update_screen;
    }
    return;
}

sub open_link {
    my $self = shift;
    if ( $self->prefix ) {
        my $href = $self->hrefs->[ $self->prefix - 1 ];
        return if !$href;

        my $url = Mojo::URL->new($href);

        if ( $url->scheme ) {
            endwin;
            system( 'xdg-open', $url->to_string );
            $self->update_screen;
        }

        my $path = $url->path;

        my $current_chapter = $self->chapters->[ $self->chapter ];
        $path = Mojo::Path->new( $current_chapter->filename )->merge($path);

        for ( my $i = 0 ; $i < @{ $self->chapters } ; $i++ ) {
            my $chapter = $self->chapters->[$i];
            if ( $chapter->filename eq $path ) {
                $self->set_chapter($i);

                if ( my $fragment = $url->fragment ) {
                    if ( my $line = $self->renderer->id_line->{$fragment} ) {
                        $self->line($line);
                    }
                }
                $self->update_screen;
                return;
            }
        }
    }
    return;
}

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
        $pad->addstring( $row, $length,
            ' = ' . $self->key_bindings->{$key} . "\n" );
        $row++;
    }

    App::termpub::Pager->new( pad => $pad )->run;

    $self->update_screen;
}

sub set_chapter {
    my ( $self, $num, $history ) = @_;
    return if !$self->chapters->[$num];
    if ( !$history ) {
        if ( $self->history_index != 0 ) {
            splice @{ $self->history }, 0, $self->history_index, $num;
        }
        else {
            unshift @{ $self->history }, $num;
        }
        $self->history_index(0);
    }
    $self->title( $self->chapters->[$num]->title );
    $self->chapter($num);
    $self->line(0);
    $self->render_pad;
    return;
}

sub history_back {
    my $self = shift;
    return if !$self->history->[ $self->history_index + 1 ];
    $self->history_index( $self->history_index + 1 );
    $self->set_chapter( $self->history->[ $self->history_index ], 1 );
    $self->update_screen;
    return;
}

sub history_forward {
    my $self = shift;
    return if $self->history_index - 1 < 0;
    $self->history_index( $self->history_index - 1 );
    $self->set_chapter( $self->history->[ $self->history_index ], 1 );
    $self->update_screen;
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
    my $self     = shift;
    my $content  = $self->chapters->[ $self->chapter ]->content;
    my $renderer = App::termpub::Renderer->new;
    $renderer->render( decode( 'UTF-8', $content ) );
    $self->renderer($renderer);
    $self->pad( $renderer->pad );
    $self->hrefs( $renderer->hrefs );
    $self->max_lines( $self->get_max_lines );
    return;
}

1;
