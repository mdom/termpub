package App::termpub::Pager::Text;
use Mojo::Base 'App::termpub::Pager';

has 'content';

has pad_columns => sub {
    my $m = 0;
    for ( split( "\n", shift->content ) ) {
        $m = length if length > $m;
    }
    return $m +1;
};

has pad_rows => sub {
    my $c = shift->content;
    $c =~ tr/\n/\n/;
};

sub render {
    my $self = shift;
    $self->pad->addstr( $self->content );
	return $self;
}

1;
