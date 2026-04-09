#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Errno qw/ENOENT EINVAL EACCES/;
use File::Temp qw/tempfile tempdir/;

my $temp_dir_name = tempdir( CLEANUP => 1 );

my $file = "$temp_dir_name/a";
open( my $fh, ">", $file ) or die;
print $fh "abc\n";
close $fh;

my $symlink     = "$temp_dir_name/b";
my $bad_symlink = "$temp_dir_name/c";
CORE::symlink( "a",        $symlink );
CORE::symlink( "notafile", $bad_symlink );

use Test::MockFile qw< nostrict >;

note "-------------- REAL MODE --------------";
$! = 0;
is( CORE::readlink("$temp_dir_name/missing_file"), undef,  "readlink on missing file " );
is( $! + 0,                                        ENOENT, '$! is ENOENT for a missing file readlink.' );

$! = 0;
is( CORE::readlink($symlink), 'a', "readlink on a working symlink works." );
is( $! + 0,                   0,   '$! is 0 for a missing file readlink.' );

$! = 0;
is( CORE::readlink($bad_symlink), 'notafile', "readlink on a broken symlink still works." );
is( $! + 0,                       0,          '$! is 0 for a missing file readlink.' );

$! = 0;
is( CORE::readlink($file), undef,  "readlink on a file is undef." );
is( $! + 0,                EINVAL, '$! is EINVAL for a readlink on a file.' );

$! = 0;
is( CORE::readlink($temp_dir_name), undef,  "readlink on a dir is undef." );
is( $! + 0,                         EINVAL, '$! is EINVAL for a readlink on a dir.' );

$! = 0;
my $got = 'abc';
like( warning { $got = CORE::readlink(undef) }, qr/^Use of uninitialized value in readlink at /, "Got expected warning for passing no value to readlink" );
is( $got, undef, "readlink without args is undef." );
# readlink(undef) errno varies by OS and version: FreeBSD 14+ returns EINVAL,
# FreeBSD 12 and Linux return ENOENT. Accept both. (GH #175)
ok( $! == EINVAL || $! == ENOENT, "\$! is EINVAL or ENOENT for a readlink(undef) (got: " . ($! + 0) . ")" );

$!   = 0;
$got = 'abc';
like( warning { $got = CORE::readlink() }, qr/^Use of uninitialized value \$_ in readlink at /, "Got expected warning for passing no value to readlink" );
is( $got, undef, "readlink without args is undef." );
ok( $! == EINVAL || $! == ENOENT, "\$! is EINVAL or ENOENT for a readlink() (got: " . ($! + 0) . ")" );

note "Cleaning up...";
CORE::unlink( $symlink, $bad_symlink, $file );

note "-------------- MOCK MODE --------------";
$temp_dir_name = '/a/random/path/not/on/disk';
$file          = "$temp_dir_name/a";
$symlink       = "$temp_dir_name/b";
$bad_symlink   = "$temp_dir_name/c";

my @mocks;
push @mocks, Test::MockFile->file( $file, "abc\n" );
push @mocks, Test::MockFile->new_dir($temp_dir_name);
push @mocks, Test::MockFile->symlink( "a",        $symlink );
push @mocks, Test::MockFile->symlink( "notafile", $bad_symlink );

$! = 0;
is( readlink("$temp_dir_name/missing_file"), undef,  "readlink on missing file " );
is( $! + 0,                                  ENOENT, '$! is ENOENT for a missing file readlink.' );

$! = 0;
is( readlink($symlink), 'a', "readlink on a working symlink works." );
is( $! + 0,             0,   '$! is 0 for a missing file readlink.' );

$! = 0;
is( readlink($bad_symlink), 'notafile', "readlink on a broken symlink still works." );
is( $! + 0,                 0,          '$! is 0 for a missing file readlink.' );

$! = 0;
is( readlink($file), undef,  "readlink on a file is undef." );
is( $! + 0,          EINVAL, '$! is EINVAL for a readlink on a file.' );

$! = 0;
is( readlink($temp_dir_name), undef,  "readlink on a dir is undef." );
is( $! + 0,                   EINVAL, '$! is EINVAL for a readlink on a dir.' );

$!   = 0;
$got = 'abc';
like( warning { $got = readlink(undef) }, qr/^Use of uninitialized value in readlink at /, "Got expected warning for passing no value to readlink" );
is( $got, undef, "readlink without args is undef." );
ok( $! == EINVAL || $! == ENOENT, "\$! is EINVAL or ENOENT for a readlink(undef) (got: " . ($! + 0) . ")" );

$!   = 0;
$got = 'abc';
todo "Something's wrong with readlink's prototype and the warning is incorrect no matter what we do in the code." => sub {
    like( warning { $got = readlink() }, qr/^Use of uninitialized value \$_ in readlink at /, "Got expected warning for passing no value to readlink" );
};
is( $got, undef, "readlink without args is undef." );
ok( $! == EINVAL || $! == ENOENT, "\$! is EINVAL or ENOENT for a readlink() (got: " . ($! + 0) . ")" );

note "--- readlink on non-existent mocks returns ENOENT ---";
{
    my $ne_file = Test::MockFile->file("$temp_dir_name/ne_file");
    $! = 0;
    is( readlink("$temp_dir_name/ne_file"), undef,  "readlink on non-existent file mock is undef" );
    is( $! + 0,                             ENOENT, '$! is ENOENT for readlink on non-existent file mock' );
}

{
    my $ne_dir = Test::MockFile->dir("$temp_dir_name/ne_dir");
    $! = 0;
    is( readlink("$temp_dir_name/ne_dir"), undef,  "readlink on non-existent dir mock is undef" );
    is( $! + 0,                            ENOENT, '$! is ENOENT for readlink on non-existent dir mock' );
}

note "--- readlink failure returns undef (not empty list) in list context ---";
{
    my $mock_file = Test::MockFile->file("$temp_dir_name/not_a_link", "data");

    # readlink on a regular file — should return (undef) in list context
    my @ret = readlink("$temp_dir_name/not_a_link");
    is( scalar @ret, 1,   'readlink on non-link returns one element in list context' );
    ok( !defined $ret[0], 'readlink failure element is undef' );
}

{
    my $mock_file = Test::MockFile->file("$temp_dir_name/nonexist");

    # readlink on a non-existent mock — should return (undef) in list context
    my @ret = readlink("$temp_dir_name/nonexist");
    is( scalar @ret, 1,   'readlink on non-existent mock returns one element in list context' );
    ok( !defined $ret[0], 'readlink non-existent failure element is undef' );
}

note "--- readlink permission checks under set_user ---";

# On systems with restrictive umask, group/other bits are stripped.
umask(0);

subtest 'readlink denied when parent dir lacks execute permission' => sub {
    my $dir  = Test::MockFile->new_dir( '/perms/rlink', { mode => 0644, uid => 500, gid => 500 } );    # read+write but no execute
    my $link = Test::MockFile->symlink( 'target', '/perms/rlink/mylink' );

    # Without set_user, readlink works regardless of permissions
    $! = 0;
    is( readlink('/perms/rlink/mylink'), 'target', 'readlink succeeds without set_user' );
    is( $! + 0, 0, 'no error' );

    # As a non-owner user, parent dir has no execute → EACCES
    Test::MockFile->set_user( 1000, 1000 );
    $! = 0;
    is( readlink('/perms/rlink/mylink'), undef, 'readlink denied when parent dir lacks execute for other' );
    is( $! + 0, EACCES, '$! is EACCES' );
    Test::MockFile->clear_user();
};

subtest 'readlink allowed when parent dir has execute permission' => sub {
    my $dir  = Test::MockFile->new_dir( '/perms/rlink2', { mode => 0711, uid => 500, gid => 500 } );    # execute for all
    my $link = Test::MockFile->symlink( 'target2', '/perms/rlink2/mylink2' );

    Test::MockFile->set_user( 1000, 1000 );
    $! = 0;
    is( readlink('/perms/rlink2/mylink2'), 'target2', 'readlink succeeds when parent dir has execute for other' );
    is( $! + 0, 0, 'no error' );
    Test::MockFile->clear_user();
};

subtest 'readlink allowed for owner with execute permission' => sub {
    my $dir  = Test::MockFile->new_dir( '/perms/rlink3', { mode => 0100, uid => 1000, gid => 1000 } );    # owner execute only
    my $link = Test::MockFile->symlink( 'target3', '/perms/rlink3/mylink3' );

    Test::MockFile->set_user( 1000, 1000 );
    $! = 0;
    is( readlink('/perms/rlink3/mylink3'), 'target3', 'readlink succeeds for owner with execute' );
    is( $! + 0, 0, 'no error' );
    Test::MockFile->clear_user();
};

subtest 'readlink allowed for root regardless of permissions' => sub {
    my $dir  = Test::MockFile->new_dir( '/perms/rlink4', { mode => 0700, uid => 500, gid => 500 } );
    my $link = Test::MockFile->symlink( 'target4', '/perms/rlink4/mylink4' );

    # Restrict: only owner can execute, no group/other access
    chmod 0100, '/perms/rlink4';

    Test::MockFile->set_user( 0, 0 );
    $! = 0;
    is( readlink('/perms/rlink4/mylink4'), 'target4', 'readlink succeeds for root even with 0000 parent' );
    is( $! + 0, 0, 'no error' );
    Test::MockFile->clear_user();
};

subtest 'readlink group execute permission' => sub {
    my $dir  = Test::MockFile->new_dir( '/perms/rlink5', { mode => 0010, uid => 500, gid => 2000 } );    # group execute only
    my $link = Test::MockFile->symlink( 'target5', '/perms/rlink5/mylink5' );

    # User in the group → allowed
    Test::MockFile->set_user( 1000, 1000, 2000 );
    $! = 0;
    is( readlink('/perms/rlink5/mylink5'), 'target5', 'readlink succeeds for group member with execute' );
    is( $! + 0, 0, 'no error' );
    Test::MockFile->clear_user();

    # User NOT in the group → denied
    Test::MockFile->set_user( 1000, 1000 );
    $! = 0;
    is( readlink('/perms/rlink5/mylink5'), undef, 'readlink denied for non-group-member without other execute' );
    is( $! + 0, EACCES, '$! is EACCES' );
    Test::MockFile->clear_user();
};

done_testing();
