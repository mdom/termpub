package App::termpub::Epub::Chapter;
use Mojo::Base -base;

has 'archive';
has 'title';
has 'filename';
has 'href';
has content => sub {
    my $self = shift;
    $self->archive->contents( $self->filename );
};

1;
