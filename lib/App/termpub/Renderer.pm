package App::termpub::Renderer;
use Mojo::Base -base;

use Mojo::DOM;
use Curses;

has column  => 0;
has columns => 80;
has rows    => 1000;
has row     => 1;
has pad     => sub { my $self = shift; newpad( $self->rows, $self->columns ) };
has buffered_newline => 0;
has left_margin      => 0;
has ol_stack         => sub { [] };
has hrefs            => sub { [] };

has preserve_whitespace => 0;

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

my %before = (
    br => sub {
        my ( $self, $node ) = @_;
        $self->newline(1);
    },
    hr => sub {
        my ( $self, $node ) = @_;
        $self->textnode('------');
    },
    img => sub {
        my ( $self, $node ) = @_;
        if ( $node->attr('alt') ) {
            $self->textnode( '[' . $node->attr('alt') . ']' );
        }
    },
    li => sub {
        my ( $self, $node ) = @_;
        my $parent_tag = $node->parent->tag;
        if ( $parent_tag eq 'ul' ) {
            $self->textnode('* ');
        }
        elsif ( $parent_tag eq 'ol' ) {
            $self->textnode( $self->ol_stack->[-1]++ . '. ' );
        }
    },
    ol => sub {
        my ( $self, $node ) = @_;
        push @{ $self->ol_stack }, 1;
        if ( $node->parent->tag eq 'li' ) {
            $self->newline(1);
        }
    },
    ul => sub {
        my ( $self, $node ) = @_;
        if ( $node->parent->tag eq 'li' ) {
            $self->newline(1);
        }
    },
    a => sub {
        my ( $self, $node ) = @_;
        my $href = $node->attr('href');
        if ($href) {
            push @{ $self->hrefs }, $href;
            $self->textnode( '[' . scalar @{ $self->hrefs } . ']' );
        }
    },
);

my %after = (
    ol => sub {
        my $self = shift;
        pop @{ $self->ol_stack };
    },
);

sub render {
    my ( $self, $content ) = @_;
    my $node = Mojo::DOM->new($content)->at('body');
    return if !$node;
    $self->process_node($node);
    $self->pad->resize( $self->row, $self->columns );
    my ( $rows, $columns );
    $self->pad->getmaxyx( $rows, $columns );
    return ( $self->pad, $self->hrefs );
}

sub incr {
    my ( $self, $attr, $val ) = @_;
    return $self->$attr( $self->$attr + $val );
}

sub decr {
    my ( $self, $attr, $val ) = @_;
    return $self->$attr( $self->$attr - $val );
}

sub process_node {
    my ( $self, $node, %args ) = @_;

    foreach my $node ( $node->child_nodes->each ) {
        if ( $node->type eq 'text' ) {
            $self->textnode( $node->content );
        }
        elsif ( $node->type eq 'tag' ) {
            my $tag = lc $node->tag;

            $self->pad->attron( $attrs{$tag} ) if $attrs{$tag};
            $before{$tag}->( $self, $node ) if $before{$tag};

            $self->incr( left_margin => $left_margin{$tag} )
              if $left_margin{$tag};

            $self->incr( preserve_whitespace => 1 ) if $tag =~ /pre|code/;

            $self->process_node($node);

            $self->decr( preserve_whitespace => 1 ) if $tag =~ /pre|code/;

            $self->pad->attroff( $attrs{$tag} ) if $attrs{$tag};

            $self->buffered_newline( $vspace{$tag} || 2 ) if $block{$tag};
            $after{$tag}->( $self, $node ) if $after{$tag};

            $self->decr( left_margin => $left_margin{$tag} )
              if $left_margin{$tag};
        }
    }
    return;
}

sub textnode {
    my ( $self, $content ) = @_;

    if ( $self->buffered_newline && $content !~ /^\s*$/ ) {
        $self->newline( $self->buffered_newline );
        $self->buffered_newline(0);
    }

    $content =~ s/\.\s\.\s\./.../;
    my @words = grep { $_ ne '' } split( /(\s+)/, $content );

    if ( !$self->preserve_whitespace ) {
        @words = map { s/\s+/ /; $_ } @words;
    }
    else {
        @words = map { split /(\n)/ } @words;
    }

    my $buffer;
    my $left_margin       = $self->left_margin;
    my $columns           = $self->columns;
    my $reduce_whitespace = !$self->preserve_whitespace;

    for my $word (@words) {
        my $length = length($word);

        my $max = $columns - $self->column - $left_margin;
        if ( $length > $max ) {
            $self->newline(1);
        }
        if ( $word =~ /^\n$/ ) {
            $self->newline(1);
            next;
        }

        next if $reduce_whitespace && $self->column == 0 && $word =~ /^\s+$/;

        if ( $left_margin && $self->column == 0 ) {
            my ( $row, $column );
            getyx( $self->pad, $row, $column );
            $self->pad->move( $row, $left_margin );
            $self->column($left_margin);
        }

        $self->pad->addstring($word);
        $self->column( $self->column + $length );
    }
    return;
}

sub newline {
    my ( $self, $amount ) = @_;
    $amount ||= 1;

    if ( !$self->preserve_whitespace ) {
        return if $self->row == 0 && $self->column == 0;

        my ( $row, $column );
        getyx( $self->pad, $row, $column );
        $self->pad->move( $row, 0 );
        my $s = $self->pad->instring;
        if ( $s =~ /^\s*$/ ) {
            $self->column(0);
            return;
        }
        $self->pad->move( $row, $column );
    }

    ## Increase pad size when we reach $self->rows
    if ( $self->row + $amount >= $self->rows ) {
        $self->rows( $self->rows + 1000 );
        resize( $self->pad, $self->rows, $self->columns );
    }
    $self->pad->addstring( "\n" x $amount );
    $self->row( $self->row + $amount );
    $self->column(0);
}

1;
