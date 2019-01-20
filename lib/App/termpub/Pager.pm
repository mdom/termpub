package App::termpub::Pager;
use Mojo::Base -base;
use Curses;

has line => 0;
has 'rows';
has 'columns';
has 'pad';
has max_lines => sub {
    shift->get_max_lines;
};

sub get_max_lines {
    my $self = shift;
    my ( $rows, $columns );
    $self->pad->getmaxyx( $rows, $columns );
    return $rows;
}

has key_bindings => sub {
    return {
        Curses::KEY_DOWN      => 'next_line',
        Curses::KEY_UP        => 'prev_line',
        ' '                   => 'next_page',
        Curses::KEY_NPAGE     => 'next_page',
        Curses::KEY_PPAGE     => 'prev_page',
        Curses::KEY_BACKSPACE => 'prev_page',
        Curses::KEY_HOME      => 'first_page',
        Curses::KEY_END       => 'last_page',
        'q'                   => 'quit',
    };
};

sub run {
    my $self = shift;
    keypad(1);

    my ( $rows, $columns );
    getmaxyx( $rows, $columns );
    $self->rows( $rows - 1 );
    $self->columns($columns);

    $self->update_screen;

    while (1) {
        my $c      = getchar;
        my $method = $self->key_bindings->{$c};
        next           if !$method;
        last           if $method eq 'quit';
        $self->$method if $method;
    }
    return;
}

sub next_line {
    my $self = shift;
    if (    $self->line + 1 <= $self->max_lines
        and $self->line + $self->rows <= $self->max_lines )
    {
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

sub first_page {
    my $self = shift;
    $self->line(0);
    $self->update_screen;
}

sub last_page {
    my $self = shift;
    my $line = $self->max_lines - $self->rows + 1;
    $self->line( $line >= 0 ? $line : 0 );
    $self->update_screen;
}

sub next_page {
    my $self = shift;
    if ( $self->line + $self->rows <= $self->max_lines ) {
        $self->line( $self->line + $self->rows );
        $self->update_screen;
        return 1;
    }
    return 0;
}

sub prev_page {
    my $self = shift;
    if ( $self->line == 0 && $self->chapter - 1 >= 0 ) {
        return 0;
    }

    if ( $self->line - $self->rows > 0 ) {
        $self->line( $self->line - $self->rows );
    }
    else {
        $self->line(0);
    }
    $self->update_screen;
    return 1;
}

sub update_screen {
    my $self = shift;
    clear;
    refresh;
    prefresh( $self->pad, $self->line, 0, 0, 0, $self->rows - 1, 80 );
}

1;