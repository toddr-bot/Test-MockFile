use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Fcntl qw( O_WRONLY O_CREAT );

use Test::MockFile qw< nostrict >;

# POSIX: newly created files/dirs/symlinks are owned by the effective uid/gid.
# When set_user() is active, the mock user's uid/gid should be applied
# to any freshly created filesystem object.

# Ensure umask doesn't interfere with permission bits in tests.
umask 0;

sub with_user (&@) {
    my ( $code, $uid, @gids ) = @_;
    Test::MockFile->set_user( $uid, @gids );
    my $ok = eval { $code->(); 1 };
    my $err = $@;
    Test::MockFile->clear_user();
    die $err unless $ok;
}

# =========================================================================
# open() creating a new file
# =========================================================================

subtest 'open(">") sets ownership to mock user' => sub {
    my $dir  = Test::MockFile->new_dir( '/own/dir1', { mode => 0777, uid => 0, gid => 0 } );
    my $file = Test::MockFile->file('/own/dir1/newfile');

    with_user {
        ok( open( my $fh, '>', '/own/dir1/newfile' ), 'open > creates file' );
        close $fh;

        my @st = stat('/own/dir1/newfile');
        is( $st[4], 1000, 'uid is mock user (1000)' );
        is( $st[5], 500,  'gid is mock primary group (500)' );
    } 1000, 500;
};

subtest 'open(">>") sets ownership to mock user' => sub {
    my $dir  = Test::MockFile->new_dir( '/own/dir2', { mode => 0777, uid => 0, gid => 0 } );
    my $file = Test::MockFile->file('/own/dir2/appendfile');

    with_user {
        ok( open( my $fh, '>>', '/own/dir2/appendfile' ), 'open >> creates file' );
        close $fh;

        my @st = stat('/own/dir2/appendfile');
        is( $st[4], 2000, 'uid is mock user (2000)' );
        is( $st[5], 2000, 'gid is mock primary group (2000)' );
    } 2000, 2000;
};

# =========================================================================
# sysopen() with O_CREAT
# =========================================================================

subtest 'sysopen(O_CREAT) sets ownership to mock user' => sub {
    my $dir  = Test::MockFile->new_dir( '/own/dir3', { mode => 0777, uid => 0, gid => 0 } );
    my $file = Test::MockFile->file('/own/dir3/sysfile');

    with_user {
        ok( sysopen( my $fh, '/own/dir3/sysfile', O_WRONLY | O_CREAT, 0644 ), 'sysopen O_CREAT creates file' );
        close $fh;

        my @st = stat('/own/dir3/sysfile');
        is( $st[4], 3000, 'uid is mock user (3000)' );
        is( $st[5], 3000, 'gid is mock primary group (3000)' );
    } 3000, 3000;
};

# =========================================================================
# mkdir()
# =========================================================================

subtest 'mkdir() sets ownership to mock user' => sub {
    my $parent = Test::MockFile->new_dir( '/own/dir4', { mode => 0777, uid => 0, gid => 0 } );
    my $child  = Test::MockFile->dir('/own/dir4/subdir');

    with_user {
        ok( mkdir( '/own/dir4/subdir', 0755 ), 'mkdir creates directory' );

        my @st = stat('/own/dir4/subdir');
        is( $st[4], 4000, 'uid is mock user (4000)' );
        is( $st[5], 100,  'gid is mock primary group (100)' );
    } 4000, 100;
};

# =========================================================================
# symlink()
# =========================================================================

subtest 'symlink() sets ownership to mock user' => sub {
    my $target = Test::MockFile->file( '/own/target', 'data', { mode => 0644, uid => 0, gid => 0 } );
    my $link   = Test::MockFile->file('/own/mylink');

    with_user {
        ok( symlink( '/own/target', '/own/mylink' ), 'symlink creates link' );

        # lstat the symlink itself (not the target)
        my @st = lstat('/own/mylink');
        is( $st[4], 5000, 'uid is mock user (5000)' );
        is( $st[5], 5000, 'gid is mock primary group (5000)' );
    } 5000, 5000;
};

# =========================================================================
# No-op without set_user
# =========================================================================

subtest 'ownership unchanged when set_user not active' => sub {
    my $dir  = Test::MockFile->new_dir( '/own/dir5', { mode => 0777, uid => 99, gid => 99 } );
    my $file = Test::MockFile->file('/own/dir5/plain');

    # No set_user — _apply_ownership is a no-op
    ok( open( my $fh, '>', '/own/dir5/plain' ), 'open > without set_user' );
    close $fh;

    my @st = stat('/own/dir5/plain');
    # Without set_user, uid/gid stay at whatever _default_mock_attrs returns (real process uid/gid)
    is( $st[4], int($>),  'uid is real process uid' );
    is( $st[5], int($)),  'gid is real process gid' );
};

# =========================================================================
# Opening existing file does NOT change ownership
# =========================================================================

subtest 'opening existing file preserves original ownership' => sub {
    my $file = Test::MockFile->file( '/own/existing', 'hello', { mode => 0666, uid => 99, gid => 99 } );

    with_user {
        ok( open( my $fh, '<', '/own/existing' ), 'open existing file for read' );
        close $fh;

        my @st = stat('/own/existing');
        is( $st[4], 99, 'uid preserved (99) for existing file' );
        is( $st[5], 99, 'gid preserved (99) for existing file' );
    } 1000, 1000;
};

subtest 'truncating existing file preserves original ownership' => sub {
    my $file = Test::MockFile->file( '/own/trunc', 'old data', { mode => 0666, uid => 88, gid => 88 } );

    with_user {
        ok( open( my $fh, '>', '/own/trunc' ), 'open existing file with >' );
        close $fh;

        my @st = stat('/own/trunc');
        is( $st[4], 88, 'uid preserved (88) for existing truncated file' );
        is( $st[5], 88, 'gid preserved (88) for existing truncated file' );
    } 1000, 1000;
};

done_testing();
