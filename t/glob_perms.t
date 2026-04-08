use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test::MockFile;

# --- Setup: directory tree with files ---
# /secret/          mode 0700, owned by root
# /secret/file.txt  regular file
# /public/          mode 0755, owned by root
# /public/file.txt  regular file
# /deep/            mode 0755
# /deep/locked/     mode 0700, owned by root (no traverse for others)
# /deep/locked/f.t  regular file

my $secret_dir  = Test::MockFile->new_dir( '/secret',          { mode => 0700, uid => 0, gid => 0 } );
my $secret_file = Test::MockFile->file( '/secret/file.txt', 'hidden' );
my $public_dir  = Test::MockFile->new_dir( '/public',          { mode => 0755, uid => 0, gid => 0 } );
my $public_file = Test::MockFile->file( '/public/file.txt', 'visible' );
my $deep_dir    = Test::MockFile->new_dir( '/deep',            { mode => 0755, uid => 0, gid => 0 } );
my $locked_dir  = Test::MockFile->new_dir( '/deep/locked',     { mode => 0700, uid => 0, gid => 0 } );
my $locked_file = Test::MockFile->file( '/deep/locked/f.t', 'buried' );

subtest 'glob without set_user shows everything' => sub {
    my @all = glob('/secret/*');
    is( \@all, ['/secret/file.txt'], 'secret file visible without permission checks' );

    @all = glob('/public/*');
    is( \@all, ['/public/file.txt'], 'public file visible' );
};

subtest 'glob as root sees everything' => sub {
    Test::MockFile->set_user( 0, 0 );

    my @secret = glob('/secret/*');
    is( \@secret, ['/secret/file.txt'], 'root sees files in mode-0700 dir' );

    my @public = glob('/public/*');
    is( \@public, ['/public/file.txt'], 'root sees files in mode-0755 dir' );

    Test::MockFile->clear_user();
};

subtest 'glob as non-owner blocked by directory read permission' => sub {
    Test::MockFile->set_user( 1000, 1000 );

    my @secret = glob('/secret/*');
    is( \@secret, [], 'non-owner cannot glob into mode-0700 dir' );

    my @public = glob('/public/*');
    is( \@public, ['/public/file.txt'], 'non-owner can glob into mode-0755 dir' );

    Test::MockFile->clear_user();
};

subtest 'glob blocked by missing execute on ancestor' => sub {
    Test::MockFile->set_user( 1000, 1000 );

    my @deep = glob('/deep/locked/*');
    is( \@deep, [], 'cannot glob into dir without execute on ancestor' );

    Test::MockFile->clear_user();
};

subtest 'glob with group permissions' => sub {
    # /group_dir/ mode 0750, owned by root:staff — group can read
    my $group_dir  = Test::MockFile->new_dir( '/group_dir',          { mode => 0750, uid => 0, gid => 50 } );
    my $group_file = Test::MockFile->file( '/group_dir/data.txt', 'group data' );

    Test::MockFile->set_user( 1000, 1000, 50 );    # user is in group 50

    my @result = glob('/group_dir/*');
    is( \@result, ['/group_dir/data.txt'], 'group member can glob into group-readable dir' );

    Test::MockFile->clear_user();

    # Now as a user NOT in the group
    Test::MockFile->set_user( 2000, 2000 );

    @result = glob('/group_dir/*');
    is( \@result, [], 'non-group user cannot glob into mode-0750 dir' );

    Test::MockFile->clear_user();
};

subtest 'glob with no-execute parent blocks traversal' => sub {
    # /noexec/ mode 0744 — readable but not executable for others
    my $noexec_dir = Test::MockFile->new_dir( '/noexec',          { mode => 0744, uid => 0, gid => 0 } );
    my $noexec_sub = Test::MockFile->new_dir( '/noexec/sub',      { mode => 0755, uid => 0, gid => 0 } );
    my $noexec_f   = Test::MockFile->file( '/noexec/sub/f.txt', 'data' );

    Test::MockFile->set_user( 1000, 1000 );

    # /noexec/* should work — parent of listed items is /noexec which has read for others (4)
    # but /noexec itself lacks execute, so traversal into it should fail
    my @r = glob('/noexec/sub/*');
    is( \@r, [], 'cannot traverse parent without execute permission' );

    Test::MockFile->clear_user();
};

done_testing();
