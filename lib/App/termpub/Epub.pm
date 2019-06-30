package App::termpub::Epub;
use Mojo::Base -base;
use Mojo::DOM;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::Util qw(decode encode html_unescape);
use Archive::Zip qw(:ERROR_CODES);
use Mojo::File 'tempfile';
use App::termpub::Epub::Chapter;

Archive::Zip::setErrorHandler( sub { } );

has 'filename';

has nav_doc => sub {
    my $self = shift;
    my $href = $self->root_dom->find('manifest item[properties="nav"]')
      ->map( attr => 'href' )->first;
    return if !$href;
    my $filename = $self->root_file->sibling($href)->to_rel->to_string;
    my $root = Mojo::Util::decode 'UTF-8', $self->archive->contents($filename);
    return Mojo::DOM->new($root);
};

has toc => sub {
    my $self = shift;
    my $toc  = $self->root_dom->find('guide reference[type="toc"]')
      ->map( attr => 'href' )->first;

    if ( !$toc ) {
        $toc = $self->root_dom->find('manifest item[properties="nav"]')
          ->map( attr => 'href' )->first;
    }

    if ( !$toc && $self->nav_doc ) {
        $toc = $self->nav_doc->find(
            'nav[epub\:type="landmarks"] a[epub\:type="toc"]')
          ->map( attr => 'href' )->first;
    }
    return if !$toc;

    for ( my $i = 0 ; $i < @{ $self->chapters } ; $i++ ) {
        if ( $self->chapters->[$i]->href eq $toc ) {
            return $i;
        }
    }
    return;
};

has start_chapter => sub {
    my $self          = shift;
    my $start_chapter = $self->root_dom->find('guide reference[type="text"]')
      ->map( attr => 'href' )->first;

    if ( !$start_chapter && $self->nav_doc ) {
        $start_chapter = $self->nav_doc->find(
            'nav[epub\:type="landmarks"] a[epub\:type="bodymatter"]')
          ->map( attr => 'href' )->first;
    }

    return 0 if !$start_chapter;

    for ( my $i = 0 ; $i < @{ $self->chapters } ; $i++ ) {
        if ( $self->chapters->[$i]->href eq $start_chapter ) {
            return $i;
        }
    }
    return 0;
};

has archive => sub {
    my $self     = shift;
    my $filename = $self->filename;
    my $archive  = Archive::Zip->new;
    if ( eval { $archive->read($filename) } != AZ_OK ) {
        die "$filename can't be unzipped (is it an epub file?)\n";
    }
    my $mimetype = $archive->contents('mimetype');
    $mimetype =~ s/[\r\n]+//;
    if ( !$mimetype ) {
        die "Missing mimetype for $filename (is it an epub file?)\n";
    }
    if ( $mimetype ne 'application/epub+zip' ) {
        die "Unknown mimetype $mimetype for $filename (is it an epub file?)\n";
    }
    return $archive;
};

has chapters => sub {
    my $self = shift;
    my @idrefs =
      $self->root_dom->find('spine itemref')->map( attr => 'idref' )->each;

    my @chapters;
    for my $idref (@idrefs) {
        my $item = $self->root_dom->at(qq{manifest item[id="$idref"]});
        next if !$item || $item->attr('media-type') ne 'application/xhtml+xml';
        my $href = $item->attr('href');
        next if !$href;

        my $title;
        if ( $self->nav_doc ) {
            my $text_node =
              $self->nav_doc->find("a[href=$href]")->map('content')->first;
            if ($text_node) {
                $title = Mojo::DOM->new($text_node)->all_text;
            }
        }

        push @chapters,
          App::termpub::Epub::Chapter->new(
            archive  => $self->archive,
            filename => $self->root_file->sibling($href)->to_rel->to_string,
            href     => $href,
            $title ? ( title => $title ) : (),
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

has language => sub {
    my $self = shift;
    return html_unescape(
        eval { $self->root_dom->at('metadata')->at('dc\:language')->content } );
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

sub read_metadata {
    my $self = shift;
    my $content =
      $self->archive->contents('META-INF/com.domgoergen.termpub.json')
      || '{}';
    my $data = decode_json($content);
    if ( $data->{version} == 1 ) {
        $data->{position} = {
            chapter => $data->{position}->[0],
            percent => $data->{position}->[1]
        };
    }
    return $data;
}

sub save_metadata {
    my ( $self, $data ) = @_;
    my ($tempfile) = tempfile;

    $self->archive->removeMember('META-INF/com.domgoergen.termpub.json');
    $self->archive->addString( encode_json($data),,
        'META-INF/com.domgoergen.termpub.json' );

    if ( $self->archive->writeToFileNamed( $tempfile->to_string ) != AZ_OK ) {
        die 'write error';
    }
    $tempfile->move_to( $self->filename );
}

1;
