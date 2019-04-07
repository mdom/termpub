package App::termpub::Hyphen;
use Mojo::Base -base;
use Mojo::File 'path';

=head1 NAME

App::termpub::Hyphen - determine positions for hyphens inside words

=head1 SYNOPSIS

This module implements Knuth-Liang algorithm to find positions inside
words where it is possible to insert hyphens to break a line.

    use Text::Hyphen;

    my $hyphenator = new Text::Hyphen;

    print $hyphenator->hyphenate('representation');
    # prints rep-re-sen-ta-tion

This is a fork of L<Text::Hyphen> to use hunspell dictionaries.

=head1 EXPORT

This version does not export anything and uses OOP interface. This
will probably change.

=head1 FUNCTIONS

=cut

has lang       => 'en_US';
has min_word   => 5;
has min_prefix => 2;
has min_suffix => 2;
has trie       => sub {
    shift->_load_patterns;
};

has dir => sub {
    for (
        qw(
        /usr/local/share/hyphen
        /usr/share/hyphen
        )
      )
    {
        return path($_) if -d;
    }
    return;
};

has file => sub {
    my $self = shift;

    my $lang = $self->lang;

    my $file;
    if ( $lang !~ /[_-]/ ) {
        $lang = lc($lang);
        $file = $self->dir->list->grep(
            sub { $_->basename =~ /^hyph_${lang}_.*\.dic/ } )->first;
    }
    else {
        $lang =~ s/-/_/;
        $lang =~ s/([^_]+)_(.+)/lc($1)."_".uc($2)/e;
        $file = $self->dir->child("hyph_$lang.dic");
    }

    return if !( $file && -f $file );
    return $file;
};

sub installed {
    my $self = shift;
    return if !$self->dir;
    return if !$self->file;
    return 1;
}

=head2 new(%options)

Creates the hyphenator object.

You can pass several options:

=over

=item min_word

Minimum length of word to be hyphenated. Shorter words are returned
right away. Defaults to 5.

=item min_prefix

Minimal prefix to leave without any hyphens. Defaults to 2.

=item min_suffix

Minimal suffix to leave wothout any hyphens. Defaults to 2.

=back

=cut

sub _add_pattern {
    my ( $self, $trie, $pattern ) = @_;

    # Convert the a pattern like 'a1bc3d4' into a string of chars 'abcd'
    # and a list of points [ 1, 0, 3, 4 ].
    my @chars = grep { /\D/ } split //, $pattern;
    my @points = map { $_ || 0 } split /\D/, $pattern, -1;

    # Insert the pattern into the tree.  Each character finds a dict
    # another level down in the tree, and leaf nodes have the list of
    # points.
    my $t = $trie;
    foreach (@chars) {
        $t->{$_} or $t->{$_} = {};
        $t = $t->{$_};
    }
    $t->{_} = \@points;
}

sub _load_patterns {
    my $self     = shift;
    my $trie     = {};
    my $fh       = $self->file->open('<');
    my $encoding = <$fh>;
    if ( $encoding eq 'ISO8859-1' ) {
        $fh->binmode(':encoding(iso-8859-1)');
    }
    while (<$fh>) {
        chomp;
        next if /^\s*#/;
        next if /^\s*$/;
        $self->_add_pattern( $trie, $_ );
    }
    return $trie;
}

=head2 hyphenate($word, [$delim])

Hyphenates the C<$word> by inserting C<$delim> into hyphen positions.
C<$delim> defaults to dash ("-").

=cut

sub hyphenate {
    my ( $self, $word, $delim ) = @_;
    $delim ||= '-';

    # Short words aren't hyphenated.
    length($word) < $self->min_word
      and return $word;

    my @word = split //, $word;

    my @work = ( '.', map { lc } @word, '.' );
    my $points = [ (0) x ( @work + 1 ) ];
    foreach my $i ( 0 .. $#work ) {
        my $t = $self->trie;
        for my $c ( @work[ $i .. $#work ] ) {
            last unless $t->{$c};

            $t = $t->{$c};
            if ( my $p = $t->{_} ) {
                for my $j ( 0 .. $#$p ) {

                    #$points->[$i + $j] = max($points->[$i + $j], $p->[$j]);
                    $points->[ $i + $j ] < $p->[$j]
                      and $points->[ $i + $j ] = $p->[$j];
                }
            }
        }

        # No hyphens in the first two chars or the last two.
        $points->[$_] = 0 foreach 0 .. $self->min_prefix;
        $points->[$_] = 0 foreach -$self->min_suffix - 1 .. -2;
    }

    # Examine the points to build the pieces list.
    my @pieces = ('');
    foreach my $i ( 0 .. length($word) - 1 ) {
        $pieces[-1] .= $word[$i];
        $points->[ 2 + $i ] % 2
          and push @pieces, '';
    }

    return wantarray ? @pieces : join( $delim, @pieces );
}

=head1 AUTHOR

Alex Kapranoff, C<< <kappa at cpan.org> >>

Mario Domgörgen C<< <mario at domgoergen.com> >>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008 Alex Kapranoff.
Copyright 2019 Mario Domgörgen.

This program is released under the following license: BSD.

=cut

1;
