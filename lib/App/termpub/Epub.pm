package App::termpub::Epub;
use Mojo::Base -base;
use Mojo::DOM;
use Mojo::Util qw(decode encode html_unescape);
use Archive::Zip qw(:ERROR_CODES);
use Mojo::File;
use App::termpub::Epub::Chapter;

Archive::Zip::setErrorHandler( sub { } );

has 'filename';

has start_chapter => sub {
    my $self          = shift;
    my $start_chapter = $self->root_dom->find('guide reference[type="text"]')
      ->map( attr => 'href' )->first;
    return if !$start_chapter;
    my @chapters = @{ $self->chapters };
    my $i = 0;
    while ( $i < @chapters ) {
        if ( $chapters[$i]->href eq $start_chapter ) {
            return $i;
        }
        $i++;
    }
    return;
};

has archive => sub {
    my $self     = shift;
    my $filename = $self->filename;
    my $archive  = Archive::Zip->new;
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

has chapters => sub {
    my $self = shift;
    my @idrefs =
      $self->root_dom->find('spine itemref')->map( attr => 'idref' )->each;
    my @chapters;
    for my $idref (@idrefs) {
        my $item = $self->root_dom->at("manifest item#$idref");
        next if !$item || $item->attr('media-type') ne 'application/xhtml+xml';
        my $href = $item->attr('href');
        next if !$href;

        push @chapters,
          App::termpub::Epub::Chapter->new(
            archive  => $self->archive,
            filename => $self->root_file->sibling($href)->to_rel->to_string,
            href     => $href,
          );
    }
    return \@chapters;
};

has root_file => sub {
    my $self          = shift;
    my $filename      = $self->filename;
    my $container     = $self->archive->contents('META-INF/container.xml');
    my $container_dom = Mojo::DOM->new($container);
    my $root_file = $container_dom->at('rootfiles rootfile')->attr("full-path");
    if ( !$root_file ) {
        die "No root file defined for $filename\n";
    }
    return Mojo::File->new($root_file);
};

has root_dom => sub {
    my $self = shift;
    my $root = Mojo::Util::decode 'UTF-8',
      $self->archive->contents( $self->root_file->to_string );
    if ( !$root ) {
        die "Missing root file "
          . $self->root_file . " for "
          . $self->filename . "\n";
    }
    return Mojo::DOM->new($root);
};

has creator => sub {
    my $self = shift;
    return html_unescape(
        eval { $self->root_dom->at('metadata')->at('dc\:creator')->content }
          || 'Unknown' );
};

has title => sub {
    my $self = shift;
    return html_unescape(
        eval { $self->root_dom->at('metadata')->at('dc\:title')->content }
          || 'Unknown' );
};

1;
