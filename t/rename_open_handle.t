use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Test::MockFile qw< nostrict >;

subtest 'read continues after rename' => sub {
    my $old = Test::MockFile->file( '/fake/old.txt', 'Hello World' );
    my $new = Test::MockFile->file( '/fake/new.txt', '' );

    open( my $fh, '<', '/fake/old.txt' ) or die "open: $!";
    my $buf;
    read( $fh, $buf, 5 );
    is( $buf, 'Hello', 'read before rename' );

    rename( '/fake/old.txt', '/fake/new.txt' ) or die "rename: $!";

    # Unix semantics: open fd survives rename — data follows the inode.
    read( $fh, $buf, 6 );
    is( $buf, ' World', 'read after rename sees remaining data' );

    close $fh;
};

subtest 'write continues after rename' => sub {
    my $old = Test::MockFile->file( '/fake/w_old.txt', 'AB' );
    my $new = Test::MockFile->file( '/fake/w_new.txt', '' );

    open( my $fh, '+<', '/fake/w_old.txt' ) or die "open: $!";

    rename( '/fake/w_old.txt', '/fake/w_new.txt' ) or die "rename: $!";

    # Write should go to the new location's data.
    print $fh 'XY';
    close $fh;

    is( $new->contents, 'XY', 'write after rename lands in new mock' );
};

subtest 'tell preserved after rename' => sub {
    my $old = Test::MockFile->file( '/fake/t_old.txt', 'ABCDEF' );
    my $new = Test::MockFile->file( '/fake/t_new.txt', '' );

    open( my $fh, '<', '/fake/t_old.txt' ) or die "open: $!";
    my $buf;
    read( $fh, $buf, 3 );
    is( tell($fh), 3, 'tell before rename' );

    rename( '/fake/t_old.txt', '/fake/t_new.txt' ) or die "rename: $!";

    is( tell($fh), 3, 'tell unchanged after rename' );
    read( $fh, $buf, 3 );
    is( $buf, 'DEF', 'continue reading from correct position' );

    close $fh;
};

subtest 'multiple handles survive rename' => sub {
    my $old = Test::MockFile->file( '/fake/m_old.txt', 'DATA' );
    my $new = Test::MockFile->file( '/fake/m_new.txt', '' );

    open( my $fh1, '<', '/fake/m_old.txt' ) or die "open1: $!";
    open( my $fh2, '<', '/fake/m_old.txt' ) or die "open2: $!";

    # Advance fh1 but not fh2
    my $buf;
    read( $fh1, $buf, 2 );

    rename( '/fake/m_old.txt', '/fake/m_new.txt' ) or die "rename: $!";

    read( $fh1, $buf, 2 );
    is( $buf, 'TA', 'handle 1 continues from tell=2' );

    read( $fh2, $buf, 4 );
    is( $buf, 'DATA', 'handle 2 reads full contents from tell=0' );

    close $fh1;
    close $fh2;
};

subtest 'eof works after rename' => sub {
    my $old = Test::MockFile->file( '/fake/e_old.txt', 'AB' );
    my $new = Test::MockFile->file( '/fake/e_new.txt', '' );

    open( my $fh, '<', '/fake/e_old.txt' ) or die "open: $!";
    my $buf;
    read( $fh, $buf, 2 );

    rename( '/fake/e_old.txt', '/fake/e_new.txt' ) or die "rename: $!";

    ok( eof($fh), 'eof returns true after rename when at end' );

    close $fh;
};

done_testing();
