#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Test::MockFile qw< nostrict >;

subtest "mkdir increments parent dir nlink" => sub {
    my $parent = Test::MockFile->new_dir('/fake/parent');
    my $child  = Test::MockFile->dir('/fake/parent/child');

    my @st = stat('/fake/parent');
    is( $st[3], 2, "Parent nlink starts at 2" );

    mkdir('/fake/parent/child');

    @st = stat('/fake/parent');
    is( $st[3], 3, "Parent nlink is 3 after mkdir" );
};

subtest "multiple mkdir increments accumulate" => sub {
    my $parent = Test::MockFile->new_dir('/fake/parent');
    my $sub1   = Test::MockFile->dir('/fake/parent/sub1');
    my $sub2   = Test::MockFile->dir('/fake/parent/sub2');

    my @st = stat('/fake/parent');
    is( $st[3], 2, "Parent nlink starts at 2" );

    mkdir('/fake/parent/sub1');
    @st = stat('/fake/parent');
    is( $st[3], 3, "Parent nlink is 3 after first mkdir" );

    mkdir('/fake/parent/sub2');
    @st = stat('/fake/parent');
    is( $st[3], 4, "Parent nlink is 4 after second mkdir" );
};

subtest "rmdir decrements parent dir nlink" => sub {
    my $parent = Test::MockFile->new_dir('/fake/parent');
    my $child  = Test::MockFile->dir('/fake/parent/child');

    mkdir('/fake/parent/child');
    my @st = stat('/fake/parent');
    is( $st[3], 3, "Parent nlink is 3 after mkdir" );

    rmdir('/fake/parent/child');
    @st = stat('/fake/parent');
    is( $st[3], 2, "Parent nlink is back to 2 after rmdir" );
};

subtest "rmdir does not decrement parent nlink below 2" => sub {
    my $parent = Test::MockFile->new_dir('/fake/parent');

    # Create child dir by hand (bypassing __mkdir) to test guard against going below 2
    my $child = Test::MockFile->dir('/fake/parent/child');
    $child->{'has_content'} = 1;
    $child->{'mode'} = 040755;

    # Parent's nlink was not incremented since we bypassed __mkdir
    my @st = stat('/fake/parent');
    is( $st[3], 2, "Parent nlink starts at 2" );

    rmdir('/fake/parent/child');
    @st = stat('/fake/parent');
    is( $st[3], 2, "Parent nlink stays at 2 (does not go below)" );
};

subtest "file unlink does not affect parent nlink" => sub {
    my $parent = Test::MockFile->new_dir('/fake/parent');
    my $file   = Test::MockFile->file( '/fake/parent/file.txt', 'content' );

    my @st = stat('/fake/parent');
    is( $st[3], 2, "Parent nlink is 2 with a file child" );

    unlink('/fake/parent/file.txt');
    @st = stat('/fake/parent');
    is( $st[3], 2, "Parent nlink still 2 after file unlink" );
};

subtest "rename dir between parents updates both nlinks" => sub {
    my $parent_a   = Test::MockFile->new_dir('/fake/a');
    my $parent_b   = Test::MockFile->new_dir('/fake/b');
    my $child_in_a = Test::MockFile->dir('/fake/a/child');
    my $child_in_b = Test::MockFile->dir('/fake/b/child');

    mkdir('/fake/a/child');
    my @st_a = stat('/fake/a');
    my @st_b = stat('/fake/b');
    is( $st_a[3], 3, "Parent A nlink is 3 after mkdir" );
    is( $st_b[3], 2, "Parent B nlink is 2" );

    rename('/fake/a/child', '/fake/b/child');
    @st_a = stat('/fake/a');
    @st_b = stat('/fake/b');
    is( $st_a[3], 2, "Parent A nlink is 2 after rename out" );
    is( $st_b[3], 3, "Parent B nlink is 3 after rename in" );
};

subtest "rename dir within same parent does not change nlink" => sub {
    my $parent  = Test::MockFile->new_dir('/fake/parent');
    my $child_a = Test::MockFile->dir('/fake/parent/old');
    my $child_b = Test::MockFile->dir('/fake/parent/new');

    mkdir('/fake/parent/old');
    my @st = stat('/fake/parent');
    is( $st[3], 3, "Parent nlink is 3 after mkdir" );

    rename('/fake/parent/old', '/fake/parent/new');
    @st = stat('/fake/parent');
    is( $st[3], 3, "Parent nlink still 3 after rename within same dir" );
};

subtest "rename file does not change parent nlink" => sub {
    my $parent = Test::MockFile->new_dir('/fake/parent');
    my $file_a = Test::MockFile->file( '/fake/parent/a.txt', 'content' );
    my $file_b = Test::MockFile->file('/fake/parent/b.txt');

    my @st = stat('/fake/parent');
    is( $st[3], 2, "Parent nlink is 2 with file children" );

    rename('/fake/parent/a.txt', '/fake/parent/b.txt');
    @st = stat('/fake/parent');
    is( $st[3], 2, "Parent nlink still 2 after file rename" );
};

done_testing();
