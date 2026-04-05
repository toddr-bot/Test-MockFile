#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Tools::Warnings qw/warning/;

use Errno qw/EBADF EINVAL/;

use Test::MockFile qw< nostrict >;

# These tests verify that tied filehandle methods return the correct values
# on error, matching real Perl I/O behavior.

subtest "syswrite on read-only handle returns undef and sets EBADF" => sub {
    my $mock = Test::MockFile->file( '/tmp/ro_file', 'hello' );
    open my $fh, '<', '/tmp/ro_file' or die "open failed: $!";

    $! = 0;
    my $ret;
    my $warn = warning { $ret = syswrite( $fh, "test" ) };
    ok( !defined $ret, 'syswrite on read-only handle returns undef, not 0' );
    is( $! + 0, EBADF, '$! is EBADF after syswrite on read-only handle' );

    close $fh;
};

subtest "syswrite returns undef on EINVAL (non-numeric length)" => sub {
    my $mock = Test::MockFile->file( '/tmp/write_file', '' );
    open my $fh, '>', '/tmp/write_file' or die "open failed: $!";

    $! = 0;
    my $ret;
    my $warn = warning { $ret = syswrite( $fh, "hello", "abc" ) };
    ok( !defined $ret, 'syswrite with non-numeric length returns undef' );
    is( $! + 0, EINVAL, '$! is EINVAL after syswrite with non-numeric length' );

    close $fh;
};

subtest "syswrite returns undef on EINVAL (bad offset)" => sub {
    my $mock = Test::MockFile->file( '/tmp/write_file2', '' );
    open my $fh, '>', '/tmp/write_file2' or die "open failed: $!";

    $! = 0;
    my $ret;
    my $warn = warning { $ret = syswrite( $fh, "hello", 3, 100 ) };
    ok( !defined $ret, 'syswrite with offset past string returns undef' );
    is( $! + 0, EINVAL, '$! is EINVAL after syswrite with bad offset' );

    close $fh;
};

subtest "sysread on destroyed mock returns undef (not 0)" => sub {
    my $fh;
    {
        my $mock = Test::MockFile->file( '/tmp/ephemeral', 'data' );
        open $fh, '<', '/tmp/ephemeral' or die "open failed: $!";
    }
    # Mock is now out of scope — data weakref is gone

    $! = 0;
    my $buf;
    my $ret = sysread( $fh, $buf, 10 );
    ok( !defined $ret, 'sysread on destroyed mock returns undef' );
    is( $! + 0, EBADF, '$! is EBADF after sysread on destroyed mock' );

    close $fh;
};

subtest "readline on write-only handle sets EBADF" => sub {
    my $mock = Test::MockFile->file( '/tmp/wo_file', 'content' );
    open my $fh, '>', '/tmp/wo_file' or die "open failed: $!";

    $! = 0;
    my $line;
    my $warn = warning { $line = readline($fh) };
    ok( !defined $line, 'readline on write-only handle returns undef' );
    is( $! + 0, EBADF, '$! is EBADF after readline on write-only handle' );

    close $fh;
};

subtest "getc on write-only handle sets EBADF" => sub {
    my $mock = Test::MockFile->file( '/tmp/wo_file2', 'content' );
    open my $fh, '>', '/tmp/wo_file2' or die "open failed: $!";

    $! = 0;
    my $c;
    my $warn = warning { $c = getc($fh) };
    ok( !defined $c, 'getc on write-only handle returns undef' );
    is( $! + 0, EBADF, '$! is EBADF after getc on write-only handle' );

    close $fh;
};

subtest "syswrite on destroyed mock returns undef" => sub {
    my $fh;
    {
        my $mock = Test::MockFile->file( '/tmp/ephemeral2', '' );
        open $fh, '>', '/tmp/ephemeral2' or die "open failed: $!";
    }

    $! = 0;
    my $ret;
    my $warn = warning { $ret = syswrite( $fh, "test" ) };
    ok( !defined $ret, 'syswrite on destroyed mock returns undef' );
    is( $! + 0, EBADF, '$! is EBADF after syswrite on destroyed mock' );

    close $fh;
};

done_testing();
