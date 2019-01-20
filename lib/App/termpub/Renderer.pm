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

my %noshow = map { $_ => 1 } qw[base basefont bgsound meta param script style];

my %empty = map { $_ => 1 } qw[br canvas col command embed frame hr
  img is index keygen link];

my %inline = map { $_ => 1 }
  qw[a abbr area b bdi bdo big button cite code dfn em font i
  input kbd label mark meter nobr progress q rp rt ruby s
  samp small span strike strong sub sup time tt u var wbr];

my %block = map { $_ => 1 }
  qw[address applet article aside audio blockquote body caption
  center colgroup datalist del dir div dd details dl dt
  fieldset figcaption figure footer form frameset h1 h2 h3
  h4 h5 h6 head header hgroup html iframe ins legend li
  listing map marquee menu nav noembed noframes noscript
  object ol optgroup option p pre select section source summary
  table tbody td tfoot th thead title tr track ul video];

my %attrs = ( h1 => A_STANDOUT );

my %before = (
    img => sub {
        my ( $self, $node ) = @_;
        if ( $node->attr('alt') ) {
            $self->textnode( Mojo::DOM->new( '[' . $node->attr('alt') . ']' ) );
        }
    }
);

sub render {
    my ( $self, $content ) = @_;
    my $node = Mojo::DOM->new($content)->at('body');
    return '' if !$node;
    $self->process_node($node);
    return ( $self->pad, $self->row );
}

sub process_node {
    my ( $self, $node, %args ) = @_;

    foreach my $node ( $node->child_nodes->each ) {
        if ( $node->type eq 'text' ) {
            $self->textnode($node);
        }
        elsif ( $node->type eq 'tag' ) {
            my $tag = lc $node->tag;

            $self->pad->attron( $attrs{$tag} ) if $attrs{$tag};
            $before{$tag}->( $self, $node ) if $before{$tag};

            $self->process_node($node);
            $self->pad->attroff( $attrs{$tag} ) if $attrs{$tag};

            $self->buffered_newline(2) if $block{$tag};
        }
    }
    return;
}

sub textnode {
    my ( $self, $node ) = @_;
    if ( $self->buffered_newline && $node->content !~ /^\s*$/ ) {
        $self->newline( $self->buffered_newline );
        $self->buffered_newline(0);
    }
    my $content = $node->content;
    $content =~ s/\.\s\.\s\./.../;
    my @words =
      map { s/\s+/ /; $_ } grep { $_ ne '' } split( /(\s+)/, $content );

    for my $word (@words) {
        my $length = length($word);
        my $max    = $self->columns - $self->column - 2;
        if ( $length > $max ) {
            $self->newline;
        }
        next if $self->column == 0 && $word =~ /^\s+$/;
        $self->pad->addstring($word);
        $self->column( $self->column + $length );
    }
    return;
}

sub newline {
    my ( $self, $amount ) = @_;
    $amount ||= 1;

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
