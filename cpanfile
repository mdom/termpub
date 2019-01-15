on configure => sub {
    requires 'Module::Build::Tiny', '0.035';
    requires 'perl', '5.010_001';
    requires 'Mojolicious';
	requires 'Archive::Zip';
	requires 'Curses';
};
