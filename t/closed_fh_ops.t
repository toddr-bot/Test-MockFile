#!/usr/bin/perl -w

# Test that I/O operations on a closed mocked filehandle behave the same
# as real Perl: warn, set appropriate error indicators, and return the
# correct failure values.  Prior to the fix, all of these operations
# silently succeeded on closed mocked handles.

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Warnings qw/warning/;

use Test::MockFile qw< nostrict >;

# --- print on closed handle ---
subtest 'print on closed handle returns undef and warns' => sub {
    my $mock = Test::MockFile->file( '/tmp/closed_print.txt', 'hello' );
    open my $fh, '>', '/tmp/closed_print.txt' or die "open: $!";
    close $fh or die "close: $!";

    my $ret;
    my $w = warning { $ret = print $fh 'should fail' };

    ok( !defined $ret, 'print returns undef on closed handle' );
    like( $w, qr/closed filehandle/i, 'warning mentions closed filehandle' );
};

# --- syswrite on closed handle ---
subtest 'syswrite on closed handle returns undef and warns' => sub {
    my $mock = Test::MockFile->file( '/tmp/closed_syswrite.txt', 'hello' );
    open my $fh, '>', '/tmp/closed_syswrite.txt' or die "open: $!";
    close $fh or die "close: $!";

    my $ret;
    my $w = warning { $ret = syswrite( $fh, 'fail', 4 ) };

    ok( !defined $ret, 'syswrite returns undef on closed handle' );
    like( $w, qr/closed filehandle/i, 'warning mentions closed filehandle' );
};

# --- read on closed handle ---
subtest 'read on closed handle returns undef and warns' => sub {
    my $mock = Test::MockFile->file( '/tmp/closed_read.txt', 'hello' );
    open my $fh, '<', '/tmp/closed_read.txt' or die "open: $!";
    close $fh or die "close: $!";

    my $ret;
    my $buf;
    my $w = warning { $ret = read( $fh, $buf, 10 ) };

    ok( !defined $ret, 'read returns undef on closed handle' );
    like( $w, qr/closed filehandle/i, 'warning mentions closed filehandle' );
};

# --- readline on closed handle ---
subtest 'readline on closed handle returns undef and warns' => sub {
    my $mock = Test::MockFile->file( '/tmp/closed_readline.txt', "line1\n" );
    open my $fh, '<', '/tmp/closed_readline.txt' or die "open: $!";
    close $fh or die "close: $!";

    my $ret;
    my $w = warning { $ret = readline($fh) };

    ok( !defined $ret, 'readline returns undef on closed handle' );
    like( $w, qr/closed filehandle/i, 'warning mentions closed filehandle' );
};

# --- tell on closed handle ---
subtest 'tell on closed handle returns -1 and warns' => sub {
    my $mock = Test::MockFile->file( '/tmp/closed_tell.txt', 'hello' );
    open my $fh, '<', '/tmp/closed_tell.txt' or die "open: $!";
    close $fh or die "close: $!";

    my $ret;
    my $w = warning { $ret = tell($fh) };

    is( $ret, -1, 'tell returns -1 on closed handle' );
    like( $w, qr/closed filehandle/i, 'warning mentions closed filehandle' );
};

# --- seek on closed handle ---
subtest 'seek on closed handle returns false and warns' => sub {
    my $mock = Test::MockFile->file( '/tmp/closed_seek.txt', 'hello' );
    open my $fh, '<', '/tmp/closed_seek.txt' or die "open: $!";
    close $fh or die "close: $!";

    my $ret;
    my $w = warning { $ret = seek( $fh, 0, 0 ) };

    ok( !$ret, 'seek returns false on closed handle' );
    like( $w, qr/closed filehandle/i, 'warning mentions closed filehandle' );
};

# --- eof on closed handle ---
subtest 'eof on closed handle returns true' => sub {
    my $mock = Test::MockFile->file( '/tmp/closed_eof.txt', 'hello' );
    open my $fh, '<', '/tmp/closed_eof.txt' or die "open: $!";
    close $fh or die "close: $!";

    # Real Perl: eof on closed handle returns 1 (no warning)
    my $ret = eof($fh);
    ok( $ret, 'eof returns true on closed handle' );
};

# --- getc on closed handle ---
subtest 'getc on closed handle returns undef and warns' => sub {
    my $mock = Test::MockFile->file( '/tmp/closed_getc.txt', 'hello' );
    open my $fh, '<', '/tmp/closed_getc.txt' or die "open: $!";
    close $fh or die "close: $!";

    my $ret;
    my $w = warning { $ret = getc($fh) };

    ok( !defined $ret, 'getc returns undef on closed handle' );
    like( $w, qr/closed filehandle/i, 'warning mentions closed filehandle' );
};

# --- double close returns false ---
subtest 'double close returns false' => sub {
    my $mock = Test::MockFile->file( '/tmp/closed_double.txt', 'hello' );
    open my $fh, '>', '/tmp/closed_double.txt' or die "open: $!";
    close $fh or die "close: $!";

    my $ret = close $fh;

    ok( !$ret, 'double close returns false' );
};

done_testing;
