#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::V0;

use Test::MockFile qw< nostrict >;

# Two-arg open: Perl strips leading/trailing whitespace from the filename
# portion after extracting the mode prefix. MockFile must do the same.

subtest 'read mode with space after <' => sub {
    my $mock = Test::MockFile->file( '/fake/ws_read', "hello\n" );

    open( my $fh, '< /fake/ws_read' ) or do { fail("open failed: $!"); return };
    is( <$fh>, "hello\n", "read correct content" );
    close $fh;
};

subtest 'write mode with space after >' => sub {
    my $mock = Test::MockFile->file( '/fake/ws_write', 'original' );

    open( my $fh, '> /fake/ws_write' ) or do { fail("open failed: $!"); return };
    print $fh "replaced";
    close $fh;
    is( $mock->contents, "replaced", "content was written" );
};

subtest 'append mode with space after >>' => sub {
    my $mock = Test::MockFile->file( '/fake/ws_append', 'base' );

    open( my $fh, '>> /fake/ws_append' ) or do { fail("open failed: $!"); return };
    print $fh "+extra";
    close $fh;
    is( $mock->contents, "base+extra", "content was appended" );
};

subtest 'read-write +< with space' => sub {
    my $mock = Test::MockFile->file( '/fake/ws_rw', "abcdef" );

    open( my $fh, '+< /fake/ws_rw' ) or do { fail("open failed: $!"); return };
    my $line = <$fh>;
    is( $line, "abcdef", "read-write read works" );
    close $fh;
};

subtest 'write-read +> with space' => sub {
    my $mock = Test::MockFile->file( '/fake/ws_wr', 'old' );

    open( my $fh, '+> /fake/ws_wr' ) or do { fail("open failed: $!"); return };
    print $fh "new";
    close $fh;
    is( $mock->contents, "new", "write-read write works" );
};

subtest 'append-read +>> with space' => sub {
    my $mock = Test::MockFile->file( '/fake/ws_ar', 'start' );

    open( my $fh, '+>> /fake/ws_ar' ) or do { fail("open failed: $!"); return };
    print $fh "end";
    close $fh;
    is( $mock->contents, "startend", "append-read append works" );
};

subtest 'multiple spaces between mode and filename' => sub {
    my $mock = Test::MockFile->file( '/fake/ws_multi', "multi" );

    open( my $fh, '<   /fake/ws_multi   ' ) or do { fail("open failed: $!"); return };
    is( <$fh>, "multi", "multiple spaces stripped" );
    close $fh;
};

subtest 'bare filename with leading/trailing whitespace' => sub {
    my $mock = Test::MockFile->file( '/fake/ws_bare', "bare\n" );

    open( my $fh, '  /fake/ws_bare  ' ) or do { fail("open failed: $!"); return };
    is( <$fh>, "bare\n", "bare filename whitespace stripped" );
    close $fh;
};

subtest 'tab characters stripped' => sub {
    my $mock = Test::MockFile->file( '/fake/ws_tab', "tab" );

    open( my $fh, "<\t/fake/ws_tab\t" ) or do { fail("open failed: $!"); return };
    is( <$fh>, "tab", "tabs stripped from filename" );
    close $fh;
};

subtest 'no whitespace still works (regression check)' => sub {
    my $mock = Test::MockFile->file( '/fake/ws_none', "nospace" );

    open( my $fh, '</fake/ws_none' ) or do { fail("open failed: $!"); return };
    is( <$fh>, "nospace", "no-space case still works" );
    close $fh;
};

subtest 'three-arg open unaffected (spaces in filename preserved)' => sub {
    my $mock = Test::MockFile->file( '/fake/ spacefile ', "spaced" );

    open( my $fh, '<', '/fake/ spacefile ' ) or do { fail("open failed: $!"); return };
    is( <$fh>, "spaced", "three-arg preserves spaces in filename" );
    close $fh;
};

done_testing();
