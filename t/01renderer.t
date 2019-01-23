#!/usr/bin/perl

use Mojo::Base -strict;
use Test::More;

use App::termpub::Renderer;
use Mojo::Loader 'data_section';
use Curses;

initscr;

END {
    endwin;
}

sub render_ok {
    my ( $input_file, $expected_file, $comment ) = @_;

    my $input    = data_section(__PACKAGE__)->{$input_file};
    my $expected = data_section(__PACKAGE__)->{$expected_file};
    chomp($expected);

    my $r = App::termpub::Renderer->new;
    my ( $pad, $rows ) = $r->render($input);
    my $output;
    my $i = 0;
    while ( $i < $rows ) {
        $pad->move( $i, 0 );
        $output .= $pad->instring . "\n";
        $i++;
    }
    $output =~ s/[^\S\n]+$//gm;
    is( $output, $expected, $comment );
}

render_ok( 'test01.in', 'test01.out' );
render_ok( 'test02.in', 'test02.out' );
render_ok( 'test03.in', 'test03.out' );
render_ok( 'test04.in', 'test04.out' );
render_ok( 'test05.in', 'test05.out' );
render_ok( 'test06.in', 'test06.out', 'multiple trailing empty text nodes' );
render_ok( 'test07.in', 'test07.out', 'simple list' );
render_ok( 'test08.in', 'test08.out', 'list with long content' );
render_ok( 'test09.in', 'test09.out', 'nested list' );
render_ok( 'test10.in', 'test10.out', 'pre block' );
render_ok( 'test11.in', 'test11.out', 'nested lists with content' );
render_ok( 'test12.in', 'test12.out', 'nested ordered lists' );

done_testing;

__DATA__

@@ test01.in
<body><i>foo</i></body>

@@ test01.out
foo

@@ test02.in
<body><div><p><i>foo</p></div></body>

@@ test02.out
foo

@@ test03.in
<body><div></div><p><i>foo</p><p>bar</p><div /><p></p></body>

@@ test03.out
foo

bar

@@ test04.in
<body><p>Lorem ipsum dolor sit amet, consectetur adipisici elit, sed eiusmod tempor incidunt ut labore et dolore magna aliqua.</p><p><span></span></p><p>Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquid ex ea commodi consequat.</p></body>

@@ test04.out
Lorem ipsum dolor sit amet, consectetur adipisici elit, sed eiusmod tempor
incidunt ut labore et dolore magna aliqua.

Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut
aliquid ex ea commodi consequat.

@@ test05.in
<body><p>foo</p><p> </p></body>

@@ test05.out
foo

@@ test06.in
<body><span> </span><p>foo</p><p> </p><p> </p> <span> </span></body>

@@ test06.out
foo

@@ test07.in
<body><ul><li>foo</li><li>bar</li><ul></body>

@@ test07.out
* foo
* bar

@@ test08.in
<body><ul><li>Lorem ipsum dolor sit amet, consectetur adipisici elit, sed eiusmod tempor incidunt ut labore et dolore magna aliqua.</li><li>Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquid ex ea commodi consequat.</li></ul></body>

@@ test08.out
* Lorem ipsum dolor sit amet, consectetur adipisici elit, sed eiusmod tempor
  incidunt ut labore et dolore magna aliqua.
* Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut
  aliquid ex ea commodi consequat.

@@ test09.in
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

@@ test09.out
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

