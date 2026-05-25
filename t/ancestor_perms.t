use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Errno qw( EACCES ENOENT );
use Fcntl qw( O_RDONLY O_WRONLY O_CREAT S_IFDIR );

use Test::MockFile qw< nostrict >;

# GitHub issue #390: ancestor directory permission checks missing on most
# path-based operations.  POSIX requires execute (search) permission on
# ALL ancestor directories when resolving a path.

sub with_user (&@) {
    my ( $code, $uid, @gids ) = @_;
    Test::MockFile->set_user( $uid, @gids );
    my $ok = eval { $code->(); 1 };
    my $err = $@;
    Test::MockFile->clear_user();
    die $err unless $ok;
}

# =========================================================================
# Setup:  /ancestor/blocked/deep/file
# /ancestor         — mode 0755 (traversable)
# /ancestor/blocked — mode 0700, uid=0 (non-root can't traverse)
# =========================================================================

subtest 'stat blocked by ancestor without execute' => sub {
    my $root = Test::MockFile->new_dir( '/anc_stat',                { mode => 0755, uid => 0, gid => 0 } );
    my $mid  = Test::MockFile->new_dir( '/anc_stat/blocked',        { mode => 0700, uid => 0, gid => 0 } );
    my $deep = Test::MockFile->new_dir( '/anc_stat/blocked/deep',   { mode => 0755, uid => 0, gid => 0 } );
    my $file = Test::MockFile->file( '/anc_stat/blocked/deep/f', 'data', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        my @st = stat('/anc_stat/blocked/deep/f');
        is( scalar @st, 0, 'stat fails when ancestor lacks execute' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 1000, 1000;

    # Root can traverse anything
    with_user {
        my @st = stat('/anc_stat/blocked/deep/f');
        ok( scalar @st > 0, 'root can stat through 0700 ancestor' );
    } 0, 0;
};

subtest 'open blocked by ancestor without execute' => sub {
    my $root = Test::MockFile->new_dir( '/anc_open',         { mode => 0755, uid => 0, gid => 0 } );
    my $mid  = Test::MockFile->new_dir( '/anc_open/blocked', { mode => 0700, uid => 0, gid => 0 } );
    my $file = Test::MockFile->file( '/anc_open/blocked/f', 'data', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        ok( !open( my $fh, '<', '/anc_open/blocked/f' ), 'open fails when ancestor lacks execute' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 1000, 1000;

    with_user {
        ok( open( my $fh, '<', '/anc_open/blocked/f' ), 'root can open through 0700 ancestor' );
        close $fh if $fh;
    } 0, 0;
};

subtest 'sysopen blocked by ancestor without execute' => sub {
    my $root = Test::MockFile->new_dir( '/anc_sysopen',         { mode => 0755, uid => 0, gid => 0 } );
    my $mid  = Test::MockFile->new_dir( '/anc_sysopen/blocked', { mode => 0700, uid => 0, gid => 0 } );
    my $file = Test::MockFile->file( '/anc_sysopen/blocked/f', 'data', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        ok( !sysopen( my $fh, '/anc_sysopen/blocked/f', O_RDONLY ), 'sysopen fails when ancestor lacks execute' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 1000, 1000;
};

subtest 'opendir blocked by ancestor without execute' => sub {
    my $root = Test::MockFile->new_dir( '/anc_opendir',         { mode => 0755, uid => 0, gid => 0 } );
    my $mid  = Test::MockFile->new_dir( '/anc_opendir/blocked', { mode => 0700, uid => 0, gid => 0 } );
    my $deep = Test::MockFile->new_dir( '/anc_opendir/blocked/sub', { mode => 0755, uid => 1000, gid => 1000 } );

    with_user {
        ok( !opendir( my $dh, '/anc_opendir/blocked/sub' ), 'opendir fails when ancestor lacks execute' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 1000, 1000;
};

subtest 'unlink blocked by ancestor without execute' => sub {
    my $root = Test::MockFile->new_dir( '/anc_unlink',             { mode => 0755, uid => 0, gid => 0 } );
    my $mid  = Test::MockFile->new_dir( '/anc_unlink/blocked',     { mode => 0700, uid => 0, gid => 0 } );
    my $deep = Test::MockFile->new_dir( '/anc_unlink/blocked/sub', { mode => 0777, uid => 0, gid => 0 } );
    my $file = Test::MockFile->file( '/anc_unlink/blocked/sub/f', 'data', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        ok( !unlink('/anc_unlink/blocked/sub/f'), 'unlink fails when ancestor lacks execute' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 1000, 1000;
};

subtest 'mkdir blocked by ancestor without execute' => sub {
    my $root = Test::MockFile->new_dir( '/anc_mkdir',             { mode => 0755, uid => 0, gid => 0 } );
    my $mid  = Test::MockFile->new_dir( '/anc_mkdir/blocked',     { mode => 0700, uid => 0, gid => 0 } );
    my $deep = Test::MockFile->new_dir( '/anc_mkdir/blocked/sub', { mode => 0777, uid => 0, gid => 0 } );
    my $new  = Test::MockFile->dir( '/anc_mkdir/blocked/sub/new' );

    with_user {
        ok( !mkdir('/anc_mkdir/blocked/sub/new'), 'mkdir fails when ancestor lacks execute' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 1000, 1000;
};

subtest 'rmdir blocked by ancestor without execute' => sub {
    my $root = Test::MockFile->new_dir( '/anc_rmdir',              { mode => 0755, uid => 0, gid => 0 } );
    my $mid  = Test::MockFile->new_dir( '/anc_rmdir/blocked',      { mode => 0700, uid => 0, gid => 0 } );
    my $deep = Test::MockFile->new_dir( '/anc_rmdir/blocked/sub',  { mode => 0777, uid => 0, gid => 0 } );
    my $tgt  = Test::MockFile->new_dir( '/anc_rmdir/blocked/sub/empty', { mode => 0755, uid => 1000, gid => 1000 } );

    with_user {
        ok( !rmdir('/anc_rmdir/blocked/sub/empty'), 'rmdir fails when ancestor lacks execute' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 1000, 1000;
};

subtest 'rename blocked by ancestor without execute' => sub {
    my $root = Test::MockFile->new_dir( '/anc_rename',            { mode => 0755, uid => 0, gid => 0 } );
    my $mid  = Test::MockFile->new_dir( '/anc_rename/blocked',    { mode => 0700, uid => 0, gid => 0 } );
    my $src  = Test::MockFile->file( '/anc_rename/blocked/old', 'x', { mode => 0644, uid => 1000, gid => 1000 } );
    my $dst  = Test::MockFile->file( '/anc_rename/blocked/new',      { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        ok( !rename( '/anc_rename/blocked/old', '/anc_rename/blocked/new' ), 'rename fails when ancestor lacks execute' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 1000, 1000;
};

subtest 'symlink blocked by ancestor without execute' => sub {
    my $root = Test::MockFile->new_dir( '/anc_sym',         { mode => 0755, uid => 0, gid => 0 } );
    my $mid  = Test::MockFile->new_dir( '/anc_sym/blocked', { mode => 0700, uid => 0, gid => 0 } );
    my $link = Test::MockFile->file( '/anc_sym/blocked/link' );

    with_user {
        ok( !symlink( '/some/target', '/anc_sym/blocked/link' ), 'symlink fails when ancestor lacks execute' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 1000, 1000;
};

subtest 'link blocked by ancestor without execute' => sub {
    my $root  = Test::MockFile->new_dir( '/anc_link',            { mode => 0755, uid => 0, gid => 0 } );
    my $mid   = Test::MockFile->new_dir( '/anc_link/blocked',    { mode => 0700, uid => 0, gid => 0 } );
    my $src   = Test::MockFile->file( '/anc_link/blocked/orig', 'x', { mode => 0644, uid => 0, gid => 0 } );
    my $open  = Test::MockFile->new_dir( '/anc_link/open',       { mode => 0755, uid => 0, gid => 0 } );
    my $dest  = Test::MockFile->file( '/anc_link/open/copy' );

    # Source path blocked
    with_user {
        ok( !link( '/anc_link/blocked/orig', '/anc_link/open/copy' ), 'link fails when source ancestor lacks execute' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 1000, 1000;
};

subtest 'readlink blocked by ancestor without execute' => sub {
    my $root = Test::MockFile->new_dir( '/anc_rl',         { mode => 0755, uid => 0, gid => 0 } );
    my $mid  = Test::MockFile->new_dir( '/anc_rl/blocked', { mode => 0700, uid => 0, gid => 0 } );
    my $link = Test::MockFile->symlink( '/some/target', '/anc_rl/blocked/s' );

    with_user {
        my $target = readlink('/anc_rl/blocked/s');
        ok( !defined $target, 'readlink fails when ancestor lacks execute' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 1000, 1000;
};

subtest 'chmod blocked by ancestor without execute' => sub {
    my $root = Test::MockFile->new_dir( '/anc_chmod',         { mode => 0755, uid => 0, gid => 0 } );
    my $mid  = Test::MockFile->new_dir( '/anc_chmod/blocked', { mode => 0700, uid => 0, gid => 0 } );
    my $file = Test::MockFile->file( '/anc_chmod/blocked/f', 'x', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        is( chmod( 0600, '/anc_chmod/blocked/f' ), 0, 'chmod returns 0 when ancestor lacks execute' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 1000, 1000;
};

subtest 'chown blocked by ancestor without execute' => sub {
    my $root = Test::MockFile->new_dir( '/anc_chown',         { mode => 0755, uid => 0, gid => 0 } );
    my $mid  = Test::MockFile->new_dir( '/anc_chown/blocked', { mode => 0700, uid => 0, gid => 0 } );
    my $file = Test::MockFile->file( '/anc_chown/blocked/f', 'x', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        is( chown( 1000, 1000, '/anc_chown/blocked/f' ), 0, 'chown returns 0 when ancestor lacks execute' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 1000, 1000;
};

subtest 'utime blocked by ancestor without execute' => sub {
    my $root = Test::MockFile->new_dir( '/anc_utime',         { mode => 0755, uid => 0, gid => 0 } );
    my $mid  = Test::MockFile->new_dir( '/anc_utime/blocked', { mode => 0700, uid => 0, gid => 0 } );
    my $file = Test::MockFile->file( '/anc_utime/blocked/f', 'x', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        is( utime( time, time, '/anc_utime/blocked/f' ), 0, 'utime returns 0 when ancestor lacks execute' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 1000, 1000;
};

subtest 'truncate blocked by ancestor without execute' => sub {
    my $root = Test::MockFile->new_dir( '/anc_trunc',         { mode => 0755, uid => 0, gid => 0 } );
    my $mid  = Test::MockFile->new_dir( '/anc_trunc/blocked', { mode => 0700, uid => 0, gid => 0 } );
    my $file = Test::MockFile->file( '/anc_trunc/blocked/f', 'hello', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        ok( !truncate( '/anc_trunc/blocked/f', 0 ), 'truncate fails when ancestor lacks execute' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 1000, 1000;
};

# =========================================================================
# Positive case: ancestor has execute — operations succeed
# =========================================================================

subtest 'operations succeed when all ancestors have execute' => sub {
    my $root = Test::MockFile->new_dir( '/anc_ok',          { mode => 0755, uid => 0, gid => 0 } );
    my $mid  = Test::MockFile->new_dir( '/anc_ok/open_dir', { mode => 0755, uid => 0, gid => 0 } );
    my $file = Test::MockFile->file( '/anc_ok/open_dir/f', 'data', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        my @st = stat('/anc_ok/open_dir/f');
        ok( scalar @st > 0, 'stat succeeds when ancestors have execute' );

        ok( open( my $fh, '<', '/anc_ok/open_dir/f' ), 'open succeeds when ancestors have execute' );
        close $fh if $fh;
    } 1000, 1000;
};

# =========================================================================
# Deep nesting: block at grandparent level
# =========================================================================

subtest 'grandparent directory blocks traversal' => sub {
    my $gp   = Test::MockFile->new_dir( '/deep_anc',            { mode => 0700, uid => 0, gid => 0 } );
    my $par  = Test::MockFile->new_dir( '/deep_anc/parent',     { mode => 0755, uid => 0, gid => 0 } );
    my $file = Test::MockFile->file( '/deep_anc/parent/f', 'data', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        ok( !open( my $fh, '<', '/deep_anc/parent/f' ), 'open blocked by grandparent without execute' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 1000, 1000;
};

# =========================================================================
# Non-mocked ancestor: traversal check is skipped (assumed OK)
# =========================================================================

subtest 'non-mocked ancestors are skipped' => sub {
    # Only mock the leaf file, not the parent dirs
    my $file = Test::MockFile->file( '/nonmocked_anc/dir/f', 'data', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        my @st = stat('/nonmocked_anc/dir/f');
        ok( scalar @st > 0, 'stat succeeds when ancestor dirs are not mocked' );
    } 1000, 1000;
};

# =========================================================================
# Filehandle-based operations bypass path traversal
# =========================================================================

subtest 'stat via filehandle bypasses ancestor check' => sub {
    my $root = Test::MockFile->new_dir( '/anc_fh',         { mode => 0755, uid => 0, gid => 0 } );
    my $mid  = Test::MockFile->new_dir( '/anc_fh/blocked', { mode => 0755, uid => 0, gid => 0 } );
    my $file = Test::MockFile->file( '/anc_fh/blocked/f', 'data', { mode => 0644, uid => 1000, gid => 1000 } );

    # Open the file while ancestor is traversable
    with_user {
        ok( open( my $fh, '<', '/anc_fh/blocked/f' ), 'open succeeds initially' );

        # Now block the ancestor
        $mid->{'mode'} = 0700 | S_IFDIR;

        # stat via filehandle should still work
        my @st = stat($fh);
        ok( scalar @st > 0, 'stat via filehandle bypasses ancestor check' );

        close $fh;
    } 1000, 1000;
};

done_testing;
