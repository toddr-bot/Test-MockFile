#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Test::MockFile qw< nostrict >;

# eof() on read-only handle: false before all data read, true at end
{
    my $mock = Test::MockFile->file( '/fake/eof_read', "hello\nworld\n" );
    open my $fh, '<', '/fake/eof_read' or die $!;

    ok( !eof($fh), "eof is false before reading" );

    my $line1 = <$fh>;
    ok( !eof($fh), "eof is false after reading first line" );

    my $line2 = <$fh>;
    ok( eof($fh), "eof is true after reading all lines" );

    close $fh;
}

# eof() on empty file: true immediately
{
    my $mock = Test::MockFile->file( '/fake/eof_empty', "" );
    open my $fh, '<', '/fake/eof_empty' or die $!;

    ok( eof($fh), "eof is true on empty file" );

    close $fh;
}

# eof() on write-only handle: true, no warning
# Real Perl: eof() on a write-only handle returns true without warning.
{
    my $mock = Test::MockFile->file( '/fake/eof_wo', "" );
    open my $fh, '>', '/fake/eof_wo' or die $!;

    ok( eof($fh), "eof is true on write-only handle" );

    close $fh;
}

# eof() on append-only handle: true, no warning
{
    my $mock = Test::MockFile->file( '/fake/eof_ao', "data" );
    open my $fh, '>>', '/fake/eof_ao' or die $!;

    ok( eof($fh), "eof is true on append-only handle" );

    close $fh;
}

# eof() on read-write handle before reading
{
    my $mock = Test::MockFile->file( '/fake/eof_rw', "content" );
    open my $fh, '+<', '/fake/eof_rw' or die $!;

    ok( !eof($fh), "eof is false on read-write handle with content" );

    close $fh;
}

# eof() after seek back to beginning
{
    my $mock = Test::MockFile->file( '/fake/eof_seek', "AB" );
    open my $fh, '<', '/fake/eof_seek' or die $!;

    my $data = <$fh>;
    ok( eof($fh), "eof is true after reading all" );

    seek( $fh, 0, 0 );
    ok( !eof($fh), "eof is false after seeking back to start" );

    close $fh;
}

# Multiple eof() calls are idempotent
{
    my $mock = Test::MockFile->file( '/fake/eof_multi', "X" );
    open my $fh, '<', '/fake/eof_multi' or die $!;

    my $c = <$fh>;
    ok( eof($fh), "eof true after read" );
    ok( eof($fh), "eof still true on second call" );
    ok( eof($fh), "eof still true on third call" );

    close $fh;
}

is( \%Test::MockFile::files_being_mocked, {}, "No mock files are in cache" );

done_testing();
exit;
