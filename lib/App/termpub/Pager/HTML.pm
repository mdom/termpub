package App::termpub::Pager::HTML;
use Mojo::Base 'App::termpub::Pager';

use Mojo::DOM;
use Curses;

has pad_columns => sub {
    my $default = 80;
    my ( $rows, $columns );
    getmaxyx( $rows, $columns );
    return $columns < $default ? $columns : $default;
    return $default;
};

has row     => 0;
has hrefs   => sub { [] };
has id_line => sub {
    {}
};

has 'hyphenator';

my %noshow =
  map { $_ => 1 } qw[base basefont bgsound meta param script style];

my %empty = map { $_ => 1 } qw[br canvas col command embed frame
  img is index keygen link];

my %inline = map { $_ => 1 }
  qw[a abbr area b bdi bdo big button cite code dfn em font i
  input kbd label mark meter nobr progress q rp rt ruby s
  samp small span strike strong sub sup time tt u var wbr];

my %block = map { $_ => 1 }
  qw[address applet article aside audio blockquote body caption
  center colgroup datalist del dir div dd details dl dt
  fieldset figcaption figure footer form frameset h1 h2 h3
  h4 h5 h6 head header hgroup hr html iframe ins legend li
  listing map marquee menu nav noembed noframes noscript
  object ol optgroup option p pre select section source summary
  table tbody td tfoot th thead title tr track ul video];

my %attrs       = ( h1 => A_STANDOUT );
my %vspace      = ( li => 1 );
my %left_margin = ( li => 2, pre => 2, code => 2 );

sub render {
    my ( $self, $content ) = @_;

    $self->row(0);
    $self->pad->clear;
    $self->pad->resize( $self->pad_rows, $self->pad_columns );
    $self->hrefs( [] );
    $self->id_line( {} );

    my $node = Mojo::DOM->new($content)->at('body');
    return if !$node;
    my $nodes = [];
    $self->process_node( $node, $nodes );

    $self->render_nodes($nodes);
    $self->pad_rows( $self->row + 1 );
    $self->pad->resize( $self->pad_rows, $self->pad_columns );
    return;
}

sub process_node {
    my ( $self, $node, $nodes ) = @_;

    foreach my $node ( $node->child_nodes->each ) {
        if ( $node->type eq 'text' ) {
            push @$nodes, [ text => $node->content ];
            next;
        }
        my $tag = lc $node->tag;

        if ( $tag eq 'hr' ) {
            push @$nodes, [ text => '--------' ];
            next;
        }
        elsif ( $tag eq 'br' ) {
            push @$nodes, [ newline => 1 ];
            next;
        }
        elsif ( $tag eq 'img' ) {
            if ( my $alt = $node->attr('alt') ) {
                my $src = $node->attr('src');
                my $num = push @{ $self->hrefs }, [ img => $src ];
                if ( $alt =~ /^\s*$/ ) {
                    $alt = $src;
                }
                push @$nodes, [ text => "[$num][$alt]" ];
            }
            next;
        }
        elsif ( $tag eq 'a' ) {
            my $href = $node->attr('href');
            if ($href) {
                push @{ $self->hrefs }, [ href => $href ];
                push @$nodes, [ text => '[' . scalar @{ $self->hrefs } . ']' ];
            }
        }
        elsif ( $tag eq 'li' ) {
            push @$nodes, [ $node->parent->tag . '_li' ];
        }
        elsif ( $tag eq 'ol' ) {
            if ( $node->parent->tag eq 'li' ) {
                push @$nodes, [ newline => 1 ];
            }
            push @$nodes, ['ol_start'];
        }
        elsif ( $tag eq 'ul' ) {
            if ( $node->parent->tag eq 'li' ) {
                push @$nodes, [ newline => 1 ];
            }
        }

        if ( my $id = $node->attr('id') ) {
            push @$nodes, [ id => $id ];
        }

        push @$nodes, [ attron => $attrs{$tag} ] if $attrs{$tag};

        push @$nodes, [ left_margin => $left_margin{$tag} ]
          if $left_margin{$tag};

        push @$nodes, [ preserve_whitespace => 1 ] if $tag =~ /pre|code/;

        $self->process_node( $node, $nodes );

        push @$nodes, [ preserve_whitespace => -1 ] if $tag =~ /pre|code/;

        push @$nodes, [ attroff => $attrs{$tag} ] if $attrs{$tag};

        push @$nodes, [ buffered_newline => $vspace{$tag} || 2 ]
          if $block{$tag};

        push @$nodes, [ left_margin => -$left_margin{$tag} ]
          if $left_margin{$tag};

        if ( $tag eq 'ol' ) {
            push @$nodes, ['ol_end'];
        }
    }
    return;
}

sub render_nodes {
    my ( $self, $nodes ) = @_;

    my $left_margin         = 0;
    my $preserve_whitespace = 0;
    my $columns             = $self->pad_columns;
    my $pad                 = '';
    my $column              = 0;
    my $newline             = 1;
    my $buffered_newline    = 0;
    my $ol_stack            = [];
    my $buffer;

    for my $node (@$nodes) {
        my ( $key, $value ) = @$node;
        my $content;

        if ( $key eq 'buffered_newline' ) {
            next if $self->row == 0 && $column == 0;
            $buffered_newline = $value;
        }
        elsif ( $key eq 'attron' ) {
            $self->add_to_pad( \$buffer );
            $self->pad->attron($value);
        }
        elsif ( $key eq 'attroff' ) {
            $self->add_to_pad( \$buffer );
            $self->pad->attroff($value);
        }
        elsif ( $key eq 'newline' ) {
            $buffer .= "\n";
            $column = 0;
        }
        elsif ( $key eq 'left_margin' ) {
            $left_margin += $value;
            $pad = ' ' x $left_margin;
        }
        elsif ( $key eq 'preserve_whitespace' ) {
            $preserve_whitespace += $value;
        }
        elsif ( $key eq 'text' ) {
            $content = $value;
        }
        elsif ( $key eq 'ol_start' ) {
            push @$ol_stack, 1;
        }
        elsif ( $key eq 'ol_end' ) {
            pop @$ol_stack;
        }
        elsif ( $key eq 'ol_li' ) {
            $content = $ol_stack->[-1]++ . '. ';
        }
        elsif ( $key eq 'ul_li' ) {
            $content = '* ';
        }
        elsif ( $key eq 'id' ) {
            my $buffered_lines = ( $buffer || '' ) =~ tr/\n/\n/;
            $self->id_line->{$value} = $self->row + $buffered_lines;
        }
        else {
            die "Unknown render instruction $key\n";
        }

        next if not defined $content;

        if ( $buffered_newline && $content !~ /^\s*$/ ) {
            $buffer .= "\n" x $buffered_newline;
            $buffered_newline = 0;
            $column           = 0;
        }

        $content =~ s/\.\s\.\s\./.../;

        my @words = grep { $_ ne '' } split( /(\s+)/, $content );

        if ( !$preserve_whitespace ) {
            @words = map { s/\s+/ /; $_ } @words;
        }
        else {
            @words = map { split /(\n)/ } @words;
        }

        my $hyphenator = $self->hyphenator;

        for my $word (@words) {

            my $length = () = $word =~ /\X/g;

            my $max = $columns - $column - $left_margin - 1;

            if ( $length > $max ) {
                next if !$preserve_whitespace && $word =~ /^\s+$/;
                if ($hyphenator) {
                    my @pieces      = $hyphenator->hyphenate($word);
                    my $need_hyphen = 0;
                    while (@pieces) {
                        my $length = () = $pieces[0] =~ /\X/g;
                        last if $length >= $max;

                        my $piece = shift @pieces;
                        $buffer .= $piece;
                        $max -= $length;
                        $need_hyphen = 1;
                    }
                    if ($need_hyphen) {
                        $buffer .= '-';
                        $word = join( '', @pieces );
                        $length = () = $word =~ /\X/g;
                    }
                }
                $buffer .= "\n";
                $column = 0;
            }

            if ( $word eq "\n" ) {
                $buffer .= "\n";
                $column = 0;
                next;
            }

            next if !$preserve_whitespace && $column == 0 && $word =~ /^\s+$/;

            if ( $left_margin && $column == 0 ) {
                $buffer .= $pad;
                $column += $left_margin;
            }

            $buffer .= $word;
            $column += $length;
        }
        $self->add_to_pad( \$buffer );
    }
    return;
}

sub add_to_pad {
    my ( $self, $buffer ) = @_;
    return if !$$buffer;
    my $buffer_rows = $$buffer =~ tr/\n/\n/;

    my $row = $self->row;

    ## Increase pad size when we reach $self->pad_rows
    if ( $row + 1 + $buffer_rows >= $self->pad_rows ) {
        $self->pad_rows( $self->pad_rows + $buffer_rows + 1000 );
        resize( $self->pad, $self->pad_rows, $self->pad_columns );
    }

    $self->pad->addstring($$buffer);
    $$buffer = '';
    $self->row( $row + $buffer_rows );
    return;
}

1;
