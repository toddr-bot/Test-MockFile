#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::V0;
use Test2::Tools::Explain;
use Test::MockFile ();

subtest 'open <& duplicates a mocked read handle' => sub {
    my $mock = Test::MockFile->file( "/tmp/dup_read", "line1\nline2\nline3\n" );
    open( my $fh, '<', '/tmp/dup_read' ) or die "open: $!";
    my $l1 = <$fh>;
    chomp $l1;
    is( $l1, 'line1', 'original read first line' );

    ok( open( my $dup, '<&', $fh ), 'dup via <& succeeds' );
    my $l2 = <$dup>;
    chomp $l2;
    is( $l2, 'line2', 'dup inherits position from source' );

    my $l3 = <$fh>;
    chomp $l3;
    is( $l3, 'line2', 'original handle position is independent after dup' );

    close($dup);
    close($fh);
};

subtest 'open >& duplicates a mocked write handle' => sub {
    my $mock = Test::MockFile->file( "/tmp/dup_write", '' );
    open( my $fh, '>', '/tmp/dup_write' ) or die "open: $!";
    print $fh "original\n";

    ok( open( my $dup, '>&', $fh ), 'dup via >& succeeds' );
    print $dup "from_dup\n";
    close($dup);
    close($fh);

    open( $fh, '<', '/tmp/dup_write' ) or die;
    my @lines = <$fh>;
    close($fh);
    chomp @lines;
    is( \@lines, [ 'original', 'from_dup' ], 'both handles wrote to same mock' );
};

subtest 'dup of +< handle inherits read-write mode' => sub {
    my $mock = Test::MockFile->file( "/tmp/dup_rw", "hello\n" );
    open( my $fh, '+<', '/tmp/dup_rw' ) or die "open: $!";

    ok( open( my $dup, '<&', $fh ), 'dup of +< handle via <&' );

    seek( $dup, 0, 0 );
    my $line = <$dup>;
    chomp $line;
    is( $line, 'hello', 'dup can read' );

    seek( $dup, 0, 2 );
    print $dup "world\n";
    close($dup);
    close($fh);

    open( $fh, '<', '/tmp/dup_rw' ) or die;
    my @lines = <$fh>;
    close($fh);
    chomp @lines;
    is( \@lines, [ 'hello', 'world' ], 'dup could write (inherited rw)' );
};

subtest 'open <&= (fdopen) works on mocked handle' => sub {
    my $mock = Test::MockFile->file( "/tmp/dup_fdopen", "content\n" );
    open( my $fh, '<', '/tmp/dup_fdopen' ) or die "open: $!";

    ok( open( my $dup, '<&=', $fh ), 'fdopen via <&= succeeds' );
    my $line = <$dup>;
    chomp $line;
    is( $line, 'content', 'fdopen handle reads correctly' );

    close($dup);
    close($fh);
};

subtest 'dup handle cleanup on scope exit' => sub {
    my $mock = Test::MockFile->file( "/tmp/dup_scope", "data\n" );
    {
        open( my $fh, '<', '/tmp/dup_scope' ) or die;
        open( my $dup, '<&', $fh ) or die;
    }
    ok( 1, 'no leak or crash when dup goes out of scope' );
};

subtest 'close on dup does not affect original' => sub {
    my $mock = Test::MockFile->file( "/tmp/dup_close", "abc\ndef\n" );
    open( my $fh, '<', '/tmp/dup_close' ) or die;
    open( my $dup, '<&', $fh ) or die;
    close($dup);

    my $line = <$fh>;
    chomp $line;
    is( $line, 'abc', 'original handle still readable after dup closed' );
    close($fh);
};

done_testing();
