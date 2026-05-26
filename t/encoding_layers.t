#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;

use Test::MockFile qw(nostrict);

# UTF-8 test data: "café" = 5 raw bytes, 4 Unicode characters
my $raw_utf8    = "caf\xc3\xa9";
my $decoded_str = "caf\x{e9}";    # U+00E9

# German: "Straße" = 7 raw bytes, 6 characters
my $raw_strasse    = "Stra\xc3\x9fe";
my $decoded_strasse = "Stra\x{df}e";

subtest 'readline with :encoding(UTF-8) in open mode' => sub {
    my $mock = Test::MockFile->file( '/tmp/enc_read', $raw_utf8 );
    open my $fh, '<:encoding(UTF-8)', '/tmp/enc_read' or die "open: $!";
    my $line = <$fh>;
    close $fh;

    is( length($line),        4, 'decoded to 4 characters' );
    ok( utf8::is_utf8($line), 'utf8 flag set' );
    is( $line, $decoded_str,  'content matches decoded string' );
};

subtest 'readline without encoding returns raw bytes' => sub {
    my $mock = Test::MockFile->file( '/tmp/enc_raw', $raw_utf8 );
    open my $fh, '<', '/tmp/enc_raw' or die "open: $!";
    my $line = <$fh>;
    close $fh;

    is( length($line),         5, '5 raw bytes' );
    ok( !utf8::is_utf8($line), 'utf8 flag NOT set' );
};

subtest 'binmode applies encoding after open' => sub {
    my $mock = Test::MockFile->file( '/tmp/enc_bm', $raw_utf8 );
    open my $fh, '<', '/tmp/enc_bm' or die "open: $!";
    binmode( $fh, ':encoding(UTF-8)' );
    my $line = <$fh>;
    close $fh;

    is( length($line),        4, 'decoded to 4 characters' );
    ok( utf8::is_utf8($line), 'utf8 flag set' );
    is( $line, $decoded_str,  'content matches' );
};

subtest ':raw removes encoding' => sub {
    my $mock = Test::MockFile->file( '/tmp/enc_raw2', $raw_utf8 );
    open my $fh, '<:encoding(UTF-8)', '/tmp/enc_raw2' or die "open: $!";

    binmode( $fh, ':raw' );
    seek( $fh, 0, 0 );
    my $line = <$fh>;
    close $fh;

    is( length($line),         5, 'back to 5 raw bytes after :raw' );
    ok( !utf8::is_utf8($line), 'utf8 flag NOT set' );
};

subtest ':utf8 shorthand works' => sub {
    my $mock = Test::MockFile->file( '/tmp/enc_utf8', $raw_utf8 );
    open my $fh, '<:utf8', '/tmp/enc_utf8' or die "open: $!";
    my $line = <$fh>;
    close $fh;

    is( length($line),        4, 'decoded to 4 characters' );
    ok( utf8::is_utf8($line), 'utf8 flag set' );
};

subtest 'print with encoding encodes to UTF-8 bytes' => sub {
    my $mock = Test::MockFile->file( '/tmp/enc_write', '' );
    open my $fh, '>:encoding(UTF-8)', '/tmp/enc_write' or die "open: $!";
    print $fh $decoded_str;
    close $fh;

    open my $raw_fh, '<', '/tmp/enc_write' or die "open: $!";
    my $raw = <$raw_fh>;
    close $raw_fh;

    is( length($raw), 5, 'written as 5 UTF-8 bytes' );
    is( $raw, $raw_utf8, 'raw bytes match expected UTF-8' );
};

subtest 'round-trip: write encoded, read decoded' => sub {
    my $mock = Test::MockFile->file( '/tmp/enc_rt', '' );

    open my $wfh, '>:encoding(UTF-8)', '/tmp/enc_rt' or die "open: $!";
    print $wfh "${decoded_strasse}\n";
    close $wfh;

    open my $rfh, '<:encoding(UTF-8)', '/tmp/enc_rt' or die "open: $!";
    my $line = <$rfh>;
    close $rfh;
    chomp $line;

    is( $line, $decoded_strasse, 'round-trip preserves content' );
    ok( utf8::is_utf8($line),   'utf8 flag set' );
};

subtest 'read() with encoding returns character count' => sub {
    my $mock = Test::MockFile->file( '/tmp/enc_read_fn', $raw_utf8 );
    open my $fh, '<:encoding(UTF-8)', '/tmp/enc_read_fn' or die "open: $!";
    my $buf;
    my $n = read( $fh, $buf, 4 );
    close $fh;

    is( $n,             4,            'read returns character count' );
    is( length($buf),   4,            'buffer has 4 characters' );
    is( $buf, $decoded_str,           'content matches decoded string' );
    ok( utf8::is_utf8($buf),          'utf8 flag set' );
};

subtest 'read() partial — fewer chars than available' => sub {
    my $mock = Test::MockFile->file( '/tmp/enc_partial', $raw_utf8 );
    open my $fh, '<:encoding(UTF-8)', '/tmp/enc_partial' or die "open: $!";
    my $buf;
    my $n = read( $fh, $buf, 2 );

    is( $n,           2,    'read returns 2' );
    is( $buf,         'ca', 'got first 2 characters' );

    my $buf2;
    $n = read( $fh, $buf2, 2 );
    is( $n,   2,                        'second read returns 2' );
    is( $buf2, "f\x{e9}",              'got remaining characters' );
    ok( utf8::is_utf8($buf2),           'utf8 flag set on second read' );
    close $fh;
};

subtest 'getc with encoding returns one decoded character' => sub {
    my $mock = Test::MockFile->file( '/tmp/enc_getc', $raw_utf8 );
    open my $fh, '<:encoding(UTF-8)', '/tmp/enc_getc' or die "open: $!";

    my @chars;
    while ( defined( my $c = getc($fh) ) ) {
        push @chars, $c;
    }
    close $fh;

    is( scalar @chars, 4, 'getc returned 4 characters' );
    is( $chars[0], 'c',          'char 0' );
    is( $chars[1], 'a',          'char 1' );
    is( $chars[2], 'f',          'char 2' );
    is( $chars[3], "\x{e9}",    'char 3 is U+00E9' );
    ok( utf8::is_utf8( $chars[3] ), 'multi-byte char has utf8 flag' );
};

subtest 'readline in list context with encoding' => sub {
    my $data = "Stra\xc3\x9fe\nCaf\xc3\xa9\n";
    my $mock = Test::MockFile->file( '/tmp/enc_list', $data );
    open my $fh, '<:encoding(UTF-8)', '/tmp/enc_list' or die "open: $!";
    my @lines = <$fh>;
    close $fh;

    is( scalar @lines, 2, 'got 2 lines' );
    chomp @lines;
    is( $lines[0], "Stra\x{df}e", 'line 1 decoded' );
    is( $lines[1], "Caf\x{e9}",   'line 2 decoded' );
};

subtest 'slurp mode with encoding' => sub {
    my $data = "line1\nline2\n";
    my $mock = Test::MockFile->file( '/tmp/enc_slurp', $data );
    open my $fh, '<:encoding(UTF-8)', '/tmp/enc_slurp' or die "open: $!";
    my $all = do { local $/; <$fh> };
    close $fh;

    is( $all, "line1\nline2\n", 'slurp content correct' );
    ok( utf8::is_utf8($all),    'utf8 flag set in slurp mode' );
};

subtest 'encoding with Latin-1 (ISO-8859-1)' => sub {
    my $raw_latin1 = "caf\xe9";    # é in Latin-1 = 1 byte
    my $mock = Test::MockFile->file( '/tmp/enc_latin1', $raw_latin1 );
    open my $fh, '<:encoding(ISO-8859-1)', '/tmp/enc_latin1' or die "open: $!";
    my $line = <$fh>;
    close $fh;

    is( length($line), 4, '4 characters' );
    is( ord( substr( $line, 3, 1 ) ), 0xe9, 'é decoded as U+00E9' );
    ok( utf8::is_utf8($line), 'utf8 flag set' );
};

done_testing;
