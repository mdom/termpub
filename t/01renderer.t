#!/usr/bin/perl

use Mojo::Base -strict;
use Test::More;

use App::termpub::Pager::HTML;
use Mojo::Loader 'data_section';
use Curses;

plan( skip_all => 'skip tests without terminal' ) if !-t STDIN;

initscr;

END {
    endwin;
}

sub render_ok {
    my ( $input_file, $expected_file, $comment ) = @_;

    my $input    = data_section(__PACKAGE__)->{$input_file};
    my $expected = data_section(__PACKAGE__)->{$expected_file};
    chomp($expected);

    my $r = App::termpub::Pager::HTML->new;
	$r->hyphenator(undef);
    $r->render($input);
    my $output;
    my $i = 0;
    while (1) {
        if ( $r->pad->move( $i, 0 ) == -1 ) {
            last;
        }
        $output .= $r->pad->instring . "\n";
        $i++;
    }
    $output =~ s/[^\S\n]+$//gm;
    is( $output, $expected, $comment );
}

my @tests = (
    'simple text with inline node',
    'deeply nested simple text node',
    'leading and trailing empty block nodes',
    'long text with over 80 characters',
    'trailing whitespace text node',
    'multiple trailing empty text nodes',
    'simple list',
    'list with long content',
    'nested list',
    'pre block',
    'nested lists with content',
    'nested ordered lists',
    'numbered links',
    'space at end of line',
);

for ( my $i = 1 ; $i <= @tests ; $i++ ) {
    render_ok( "test$i.in", "test$i.out", $tests[$i] );
}

done_testing;

__DATA__

@@ test1.in
<body><i>foo</i></body>

@@ test1.out
foo

@@ test2.in
<body><div><p><i>foo</p></div></body>

@@ test2.out
foo

@@ test3.in
<body><div></div><p><i>foo</p><p>bar</p><div /><p></p></body>

@@ test3.out
foo

bar

@@ test4.in
<body><p>Lorem ipsum dolor sit amet, consectetur adipisici elit, sed eiusmod tempor incidunt ut labore et dolore magna aliqua.</p><p><span></span></p><p>Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquid ex ea commodi consequat.</p></body>

@@ test4.out
Lorem ipsum dolor sit amet, consectetur adipisici elit, sed eiusmod tempor
incidunt ut labore et dolore magna aliqua.

Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut
aliquid ex ea commodi consequat.

@@ test5.in
<body><p>foo</p><p> </p></body>

@@ test5.out
foo

@@ test6.in
<body><span> </span><p>foo</p><p> </p><p> </p> <span> </span></body>

@@ test6.out
foo

@@ test7.in
<body><ul><li>foo</li><li>bar</li><ul></body>

@@ test7.out
* foo
* bar

@@ test8.in
<body><ul><li>Lorem ipsum dolor sit amet, consectetur adipisici elit, sed eiusmod tempor incidunt ut labore et dolore magna aliqua.</li><li>Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquid ex ea commodi consequat.</li></ul></body>

@@ test8.out
* Lorem ipsum dolor sit amet, consectetur adipisici elit, sed eiusmod tempor
  incidunt ut labore et dolore magna aliqua.
* Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut
  aliquid ex ea commodi consequat.

@@ test9.in
<body>
  <ul>
    <li>foo</li>
	<li>
      <ul>
        <li>bar</li>
        <li>quux</li>
      </ul>
    </li>
  </ul>
</body>

@@ test9.out
* foo
*
  * bar
  * quux

@@ test10.in
<body><pre>if ($foo) {
  die;
}
</pre></body>

@@ test10.out
  if ($foo) {
    die;
  }


@@ test11.in
<?xml version="1.0"?>
<body>
  <ul>
    <li>A
		<ul><li>B</li><li>C</li></ol>
  </li>
  </ul>
</body>

@@ test11.out

* A
  * B
  * C

@@ test12.in
<body>
  <ol>
    <li>foo</li>
	<li>
      <ol>
        <li>bar</li>
        <li>quux</li>
      </ul>
    </li>
    <li>foobar</li>
  </ul>
</body>

@@ test12.out
1. foo
2.
  1. bar
  2. quux
3. foobar

@@ test13.in
<body><a href="part0002.html#acknowledgments">Acknowledgments</a></body>

@@ test13.out
[1]Acknowledgments

@@ test14.in
<body>
  <p>xxxxx xxxx xxxxxx xxxxx xx xxx xxxxxxxx xxxx xx xxxxx, xxxxxxxxx xx xxxxxxxxx.</p>
  <p>Still</p>
</body>

@@ test14.out
xxxxx xxxx xxxxxx xxxxx xx xxx xxxxxxxx xxxx xx xxxxx, xxxxxxxxx xx xxxxxxxxx.

Still

