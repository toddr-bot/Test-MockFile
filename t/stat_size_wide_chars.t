#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::V0;
use Test2::Tools::Explain;
use Test::MockFile qw(nostrict);

# stat st_size must report byte count, not character count.
# Perl's length() returns characters; for strings with the UTF8 flag,
# characters < bytes.  size() now uses bytes::length().

subtest 'ASCII file — size equals character count' => sub {
    my $mock = Test::MockFile->file( '/tmp/ascii_test', 'Hello World' );
    my @st = stat('/tmp/ascii_test');
    is( $st[7], 11, 'stat size for ASCII content' );
};

subtest 'Wide characters — size must be byte count' => sub {

    # U+263A SMILEY FACE is 3 bytes in UTF-8.
    # "Hello \x{263A}" = 7 characters but 9 bytes.
    my $content = "Hello \x{263A}";
    my $mock    = Test::MockFile->file( '/tmp/wide_test', $content );

    my @st = stat('/tmp/wide_test');

    use bytes;
    my $expected_bytes = length($content);
    no bytes;
    my $chars = length($content);

    # Sanity: confirm the test data actually diverges.
    ok( $expected_bytes > $chars, "test string has more bytes ($expected_bytes) than chars ($chars)" );

    is( $st[7], $expected_bytes, 'stat size reports bytes, not characters' );
};

subtest 'Wide characters written via print' => sub {
    my $mock = Test::MockFile->file( '/tmp/wide_print_test', '' );
    open my $fh, '>', '/tmp/wide_print_test' or die "open: $!";
    {
        no warnings 'utf8';
        print $fh "caf\x{e9} \x{2603}";    # é (2 bytes) + snowman (3 bytes)
    }
    close $fh;

    my @st = stat('/tmp/wide_print_test');

    use bytes;
    my $expected = length( $mock->contents );
    no bytes;

    is( $st[7], $expected, 'stat size after print matches byte length' );
};

subtest 'Symlink size is byte length of target path' => sub {
    my $target_path = "/tmp/sym_target_\x{263A}";
    my $target      = Test::MockFile->file( $target_path, 'x' );
    my $link        = Test::MockFile->symlink( $target_path, '/tmp/sym_link_test' );

    my @lst = lstat('/tmp/sym_link_test');

    use bytes;
    my $expected = length($target_path);
    no bytes;

    is( $lst[7], $expected, 'lstat size of symlink is byte length of target' );
};

subtest 'size() method returns byte count' => sub {
    my $content = "\x{1F600}" x 5;    # 5 grinning faces, 4 bytes each = 20 bytes
    my $mock = Test::MockFile->file( '/tmp/size_method_test', $content );

    use bytes;
    my $expected = length($content);
    no bytes;

    is( $mock->size, $expected, 'size() returns byte count for wide content' );
    is( $mock->size, 20,       'size() is 20 bytes (5 × 4-byte chars)' );
};

done_testing();
