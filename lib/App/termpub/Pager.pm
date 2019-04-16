package App::termpub::Pager;
use Mojo::Base -base;
use Curses;

has line => 0;
has positions => sub { {} };

has rows => sub {
    my $self = shift;
    my ( $rows, $columns );
    getmaxyx( $rows, $columns );
    $self->columns($columns);
    $rows - 1;
};

has columns => sub {
    my $self = shift;
    my ( $rows, $columns );
    getmaxyx( $rows, $columns );
    $self->rows( $rows - 1 );
    $columns;
};

has 'title';

has pad =>
  sub { my $self = shift; newpad( $self->pad_rows, $self->pad_columns ) };

has pad_rows    => sub { shift->rows };
has pad_columns => sub { shift->columns };

has key_bindings => sub {
    return {
        Curses::KEY_DOWN      => 'next_line',
        Curses::KEY_UP        => 'prev_line',
        'k'                   => 'prev_line',
        'j'                   => 'next_line',
        ' '                   => 'next_page',
        Curses::KEY_NPAGE     => 'next_page',
        Curses::KEY_PPAGE     => 'prev_page',
        Curses::KEY_BACKSPACE => 'prev_page',
        Curses::KEY_HOME      => 'first_page',
        Curses::KEY_END       => 'last_page',
        Curses::KEY_RESIZE    => 'handle_resize',
        'q'                   => 'quit',
        'g'                   => 'goto_line',
        'G'                   => 'goto_line_or_end',
        '%'                   => 'goto_percent',
        'm'                   => 'mark_position',
        "'"                   => 'restore_position',
    };
};

has 'prefix' => '';

sub goto_position {
    my ( $self, $position ) = @_;
    if (   $position->{line}
        && $position->{columns}
        && $position->{columns} == $self->pad_columns )
    {
        $self->goto_line( $position->{line} );
    }
    else {
        $self->goto_percent( $position->{percent} );
    }
}

sub get_position {
    my $self = shift;
    return {
        percent => $self->get_percent,
        line    => $self->line,
        columns => $self->pad_columns,
    };
}

sub set_mark {
    my ( $self, $position ) = @_;
    $self->positions->{"'"} = $position || $self->get_position;
}

sub mark_position {
    my $self = shift;
    my $c    = getch();
    if ( $c =~ /[a-z]/ ) {
        $self->positions->{$c} = $self->get_position;
    }
    return;
}

sub restore_position {
    my $self = shift;
    my $c    = getch();
    if ( $c =~ /[a-z']/ ) {
        return if not exists $self->positions->{$c};
        my $old = $self->get_position;
        $self->goto_position( $self->positions->{$c} );
        $self->set_mark($old);

    }
    return;
}

sub handle_resize {
    my $self = shift;
    my ( $rows, $columns );
    getmaxyx( $rows, $columns );
    $self->rows( $rows - 1 );
    $self->columns($columns);
}

sub run {
    my $self = shift;
    keypad(1);

    $self->update_screen;

    while (1) {
        my $c = getch;
        if ( $c eq '' ) {
            $self->prefix('');
            next;
        }
        if ( $c =~ /^[0-9]$/ ) {
            $self->prefix( $self->prefix . $c );
            next;
        }
        my $method = $self->key_bindings->{$c};
        next           if !$method;
        last           if $method eq 'quit';
        $self->$method if $method;
        $self->prefix('');
    }
    return;
}

sub goto_line {
    my ( $self, $num ) = @_;
    $num ||= ( $self->prefix || 1 ) - 1;
    if ( $num <= $self->pad_rows ) {
        $self->line($num);
        $self->update_screen if $self->rows;
    }
    return;
}

sub goto_percent {
    my ( $self, $num ) = @_;
    $num ||= ( $self->prefix || 0 );
    $self->set_mark;
    $self->goto_line( int( $num * $self->pad_rows / 100 ) );
}

sub goto_line_or_end {
    my $self = shift;
    $self->set_mark;
    if ( $self->prefix ) {
        $self->goto_line;
    }
    else {
        $self->last_page;
    }
    return;
}

sub next_line {
    my $self = shift;
    if (    $self->line + 1 <= $self->pad_rows
        and $self->line + $self->rows <= $self->pad_rows )
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
    $self->set_mark;
    $self->line(0);
    $self->update_screen;
}

sub last_page {
    my $self = shift;
    $self->set_mark;
    my $line = $self->pad_rows - $self->rows + 1;
    $self->line( $line >= 0 ? $line : 0 );
    $self->update_screen;
}

sub next_page {
    my $self = shift;
    $self->set_mark;
    if ( $self->line + $self->rows <= $self->pad_rows ) {
        $self->line( $self->line + $self->rows );
        $self->update_screen;
        return 1;
    }
    return 0;
}

sub prev_page {
    my $self = shift;
    $self->set_mark;
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

sub get_percent {
    my $self = shift;
    return 0 if !$self->pad_rows;
    int( ( $self->line + 1 ) * 100 / $self->pad_rows );
}

sub update_screen {
    my $self = shift;
    clear;
    refresh;
    prefresh( $self->pad, $self->line, 0, 0, 0, $self->rows - 1, $self->pad_columns );

    move( $self->rows, 0 );
    addstring( $self->title );

    my $pos = $self->get_percent . '%';
    if ( $self->line + $self->rows - 1 >= $self->pad_rows ) {
        $pos = "end";
    }
    $pos = "($pos)";
    addstring( '-' x $self->columns );
    move( $self->rows, $self->columns - length($pos) - 2 );
    addstring($pos);

    move( $self->rows, 0 );
    chgat( -1, A_STANDOUT, 0, 0 );
}

1;
