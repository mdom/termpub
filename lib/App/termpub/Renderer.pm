package App::termpub::Renderer;
use Mojo::Base -base;

use Mojo::DOM;
use Curses;

has columns => 80;
has rows    => 1000;
has row     => 0;
has pad     => sub { my $self = shift; newpad( $self->rows, $self->columns ) };
has hrefs   => sub { [] };

my %noshow = map { $_ => 1 } qw[base basefont bgsound meta param script style];

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
    my $node = Mojo::DOM->new($content)->at('body');
    return if !$node;
    my $nodes = [];
    $self->process_node( $node, $nodes );

    $self->render_nodes($nodes);
    $self->pad->resize( $self->row + 1, $self->columns );
    return ( $self->pad, $self->hrefs );
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
            if ( $node->attr('alt') ) {
                push @$nodes, [ text => '[' . $node->attr('alt') . ']' ];
            }
            next;
        }
        elsif ( $tag eq 'a' ) {
            my $href = $node->attr('href');
            if ($href) {
                push @{ $self->hrefs }, $href;
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
    my $columns             = $self->columns;
    my $pad                 = '';
    my $column              = 0;
    my $newline             = 1;
    my $buffered_newline    = 0;
    my $ol_stack            = [];

    for my $node (@$nodes) {
        my ( $key, $value ) = @$node;
        my $content;

        if ( $key eq 'buffered_newline' ) {
            $buffered_newline = $value;
        }
        elsif ( $key eq 'attron' ) {
            $self->pad->attron($value);
        }
        elsif ( $key eq 'attroff' ) {
            $self->pad->attroff($value);
        }
        elsif ( $key eq 'newline' ) {
            $self->newline( $value, $column, $preserve_whitespace );
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
        else {
            die "Unknown render instruction $key\n";
        }

        next if not defined $content;

        if ( $buffered_newline && $content !~ /^\s*$/ ) {
            $self->newline( $buffered_newline, $column, $preserve_whitespace );
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

        for my $word (@words) {
            my $length = length($word);

            my $max = $columns - $column - $left_margin - 2;

            if ( $length > $max ) {
                $self->newline( 1, $column, $preserve_whitespace );
                $column = 0;
            }
            if ( $word eq "\n" && $preserve_whitespace ) {
                $self->newline( 1, $column, $preserve_whitespace );
                $column = 0;
                next;
            }

            next
              if !$preserve_whitespace
              && $column == 0
              && $word =~ /^\s+$/;

            if ( $left_margin && $column == 0 ) {
                $word = $pad . $word;
                $length += $left_margin;
            }

            $self->pad->addstring($word);
            $column += $length;
        }
    }
    return;
}

sub newline {
    my ( $self, $amount, $column, $preserve_whitespace ) = @_;

    return if !$preserve_whitespace && $column == 0 && $self->row == 0 ;

    ## Increase pad size when we reach $self->rows
    if ( $self->row + 1 + $amount >= $self->rows ) {
        $self->rows( $self->rows + 1000 );
        resize( $self->pad, $self->rows, $self->columns );
    }
    $self->pad->addstring( "\n" x $amount );
    $self->row( $self->row + $amount );
    return;
}

1;
