package App::termpub::Renderer;
use Mojo::Base -base;
use Mojo::DOM;
use Text::Wrap 'wrap';
use Curses;

sub render {
    my ( $self, $content ) = @_;
    my $node = Mojo::DOM->new($content)->at('body');
    return '' if !$node;
    my $output = $self->render_dom($node);
    my $pad = newpad( 10_000, 80 );
    $pad->addstr( wrap( '   ', '   ', $output ) );
	my $max_lines = $output =~ tr/\n//;
    return ($pad, $max_lines );;
}

sub render_dom {
    my ( $self, $node, $attr ) = @_;
    my $content = '';
    if ( $self->is_tag( $node, 'ul' ) ) {
        $attr = { list => 'ul' };
    }
    elsif ( $self->is_tag( $node, 'ol' ) ) {
        $attr = { list => 'ol', num => 1 };
    }
    for ( $node->child_nodes->each ) {
        $content .= $self->render_dom( $_, $attr );
    }
    if ( $node->attr('hidden') && $node->attr('hidden') eq 'hidden' ) {
        return '';
    }
    if ( $node->type eq 'text' ) {
        return $self->render_text($node);
    }
    elsif ( $node->type eq 'tag' && $node->tag =~ /^h\d+$/ ) {
        return "= $content\n\n";
    }
    elsif ( $self->is_tag( $node, 'li' ) ) {
        if ( $attr->{list} eq 'ul' ) {
            return "* $content\n";
        }
        else {
            my $num = $attr->{num}++;
            return "$num. $content\n";
        }
    }
    elsif ( $self->is_tag( $node, 'p', 'div' ) ) {
        return "$content\n\n";
    }
    return $content;
}

sub render_text {
    my ( $self, $node ) = @_;
    my $content = $node->content;
    $content =~ s/\.\s\.\s\./.../;
    return '' if $content !~ /\S/;
    return $content;
}

sub is_tag {
    my ( $self, $node, @tags ) = @_;
    return
      if $node->type ne 'tag';
    for my $tag (@tags) {
        return 1
          if $node->tag eq $tag;
    }
    return;
}

1;
