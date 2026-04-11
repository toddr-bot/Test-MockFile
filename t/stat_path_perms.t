use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Errno qw( EACCES );
use Fcntl qw( S_IFDIR );

use Test::MockFile qw< nostrict >;

# POSIX: stat() and lstat() require execute (search) permission on every
# ancestor directory in the path.  stat("/a/b/c") must fail with EACCES
# when the caller lacks execute on "/a" or "/a/b".

# Override umask so mode bits are exact
umask 0;

# =========================================================================
# Helper — run code block with a mock user, always clean up
# =========================================================================

sub with_user (&@) {
    my ( $code, $uid, @gids ) = @_;
    Test::MockFile->set_user( $uid, @gids );
    my $ok = eval { $code->(); 1 };
    my $err = $@;
    Test::MockFile->clear_user();
    die $err unless $ok;
}

# Helper — create an existing directory mock with exact mode
sub make_dir {
    my ( $path, %opts ) = @_;
    my $mode = delete $opts{'mode'} // 0755;
    my $dir = Test::MockFile->new_dir( $path, \%opts );
    # Override mode directly to avoid umask interference
    $dir->{'mode'} = S_IFDIR | $mode;
    return $dir;
}

# =========================================================================
# stat() with accessible parent directory — should succeed
# =========================================================================

subtest 'stat succeeds when parent directory allows execute' => sub {
    my $dir  = make_dir( '/sp_ok', mode => 0755, uid => 0, gid => 0 );
    my $file = Test::MockFile->file( '/sp_ok/readable', 'data', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        my @st = stat('/sp_ok/readable');
        ok( scalar @st, 'stat succeeds with execute on parent' );
    } 1000, 1000;
};

# =========================================================================
# stat() with no-execute parent — should fail with EACCES
# =========================================================================

subtest 'stat fails when parent directory lacks execute' => sub {
    my $dir  = make_dir( '/sp_noexec', mode => 0644, uid => 0, gid => 0 );
    my $file = Test::MockFile->file( '/sp_noexec/secret', 'hidden', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        my @st = stat('/sp_noexec/secret');
        ok( !scalar @st, 'stat fails with no execute on parent' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 1000, 1000;
};

# =========================================================================
# lstat() with no-execute parent — should also fail
# =========================================================================

subtest 'lstat fails when parent directory lacks execute' => sub {
    my $dir  = make_dir( '/sp_noexec_l', mode => 0644, uid => 0, gid => 0 );
    my $file = Test::MockFile->file( '/sp_noexec_l/file', 'data', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        my @st = lstat('/sp_noexec_l/file');
        ok( !scalar @st, 'lstat fails with no execute on parent' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 1000, 1000;
};

# =========================================================================
# Deep path — no execute on intermediate ancestor
# =========================================================================

subtest 'stat fails when intermediate ancestor lacks execute' => sub {
    my $top    = make_dir( '/sp_deep',            mode => 0755, uid => 0, gid => 0 );
    my $middle = make_dir( '/sp_deep/locked',     mode => 0644, uid => 0, gid => 0 );
    my $bottom = make_dir( '/sp_deep/locked/sub', mode => 0755, uid => 0, gid => 0 );
    my $file   = Test::MockFile->file( '/sp_deep/locked/sub/target', 'x', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        my @st = stat('/sp_deep/locked/sub/target');
        ok( !scalar @st, 'stat fails when intermediate dir lacks execute' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 1000, 1000;
};

# =========================================================================
# Root bypass — root can traverse directories without execute
# =========================================================================

subtest 'root bypasses execute check on parent' => sub {
    my $dir  = make_dir( '/sp_root', mode => 0600, uid => 99, gid => 99 );
    my $file = Test::MockFile->file( '/sp_root/file', 'data', { mode => 0644, uid => 99, gid => 99 } );

    with_user {
        my @st = stat('/sp_root/file');
        ok( scalar @st, 'root can stat through no-exec directory' );
    } 0, 0;
};

# =========================================================================
# Owner with execute — should succeed even if others can't
# =========================================================================

subtest 'owner with execute can stat, non-owner cannot' => sub {
    my $dir  = make_dir( '/sp_owner', mode => 0700, uid => 1000, gid => 1000 );
    my $file = Test::MockFile->file( '/sp_owner/mine', 'data', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        my @st = stat('/sp_owner/mine');
        ok( scalar @st, 'owner with execute can stat file in their dir' );
    } 1000, 1000;

    with_user {
        my @st = stat('/sp_owner/mine');
        ok( !scalar @st, 'non-owner cannot stat file in 0700 dir' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 2000, 2000;
};

# =========================================================================
# Group execute — group member can traverse
# =========================================================================

subtest 'group member with execute can stat through directory' => sub {
    my $dir  = make_dir( '/sp_group', mode => 0750, uid => 0, gid => 50 );
    my $file = Test::MockFile->file( '/sp_group/shared', 'data', { mode => 0644, uid => 0, gid => 50 } );

    with_user {
        my @st = stat('/sp_group/shared');
        ok( scalar @st, 'group member can stat through 0750 dir' );
    } 2000, 2000, 50;

    with_user {
        my @st = stat('/sp_group/shared');
        ok( !scalar @st, 'non-group-member cannot stat through 0750 dir' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 2000, 2000;
};

# =========================================================================
# No mock user — stat should work regardless of permissions
# =========================================================================

subtest 'stat ignores permissions when no mock user set' => sub {
    my $dir  = make_dir( '/sp_nouse', mode => 0000, uid => 0, gid => 0 );
    my $file = Test::MockFile->file( '/sp_nouse/file', 'data', { mode => 0000, uid => 0, gid => 0 } );

    my @st = stat('/sp_nouse/file');
    ok( scalar @st, 'stat works on 0000 dir/file without mock user' );
};

# =========================================================================
# Filehandle stat — bypasses path resolution
# =========================================================================

subtest 'stat on open filehandle bypasses path permissions' => sub {
    my $dir  = make_dir( '/sp_fh', mode => 0755, uid => 0, gid => 0 );
    my $file = Test::MockFile->file( '/sp_fh/data', 'content', { mode => 0644, uid => 1000, gid => 1000 } );

    ok( open( my $fh, '<', '/sp_fh/data' ), 'open succeeds before restricting dir' );

    # Restrict the directory after opening the handle
    $dir->{'mode'} = S_IFDIR | 0644;

    with_user {
        my @st = stat($fh);
        ok( scalar @st, 'stat on open filehandle works even with restricted parent' );
    } 1000, 1000;

    close $fh;
};

# =========================================================================
# File operators (-e, -f) use stat internally
# =========================================================================

subtest 'file test operators respect path permissions' => sub {
    my $dir  = make_dir( '/sp_ops', mode => 0644, uid => 0, gid => 0 );
    my $file = Test::MockFile->file( '/sp_ops/file', 'data', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        ok( !-e '/sp_ops/file', '-e returns false when parent lacks execute' );
        ok( !-f '/sp_ops/file', '-f returns false when parent lacks execute' );
    } 1000, 1000;
};

done_testing;
