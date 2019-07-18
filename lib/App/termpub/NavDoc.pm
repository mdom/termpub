package App::termpub::NavDoc;
use Mojo::Base -base;
use Mojo::DOM;

has 'href';
has 'epub';

sub find { shift->root->find(@_); }

has root => sub {
    my $self = shift;
    return if !$self->href;
    my $filename =
      $self->epub->root_file->sibling( $self->href )->to_rel->to_string;
    my $root = Mojo::Util::decode 'UTF-8',
      $self->epub->archive->contents($filename);
    return Mojo::DOM->new($root);
};

sub toc {
    my $self = shift;
    my $href =
      $self->find('nav[epub\:type="landmarks"] a[epub\:type="toc"]')
      ->map( attr => 'href' )->first;

    return if !$href;
    return Mojo::URL->new($href)->base( $self->href )->to_abs;
}

1;
