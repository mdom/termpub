package App::termpub::Epub::Chapter;
use Mojo::Base -base;

has 'archive';
has 'title';
has 'filename';
has 'href';
has title => sub {
	shift->dom->find('title')->map('content')->first;
};
has content => sub {
    my $self = shift;
    $self->archive->contents( $self->filename );
};

has dom => sub {
	Mojo::DOM->new( shift->content );
};

1;
