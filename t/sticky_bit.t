use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Errno qw( EACCES );
use Fcntl qw( S_IFDIR );

use Test::MockFile qw< nostrict >;

# POSIX sticky bit (S_ISVTX / 01000) enforcement:
# When a directory has the sticky bit set, only the file owner,
# the directory owner, or root may delete/rename entries in it.
# Classic example: /tmp (mode 1777).

# =========================================================================
# Helpers
# =========================================================================

sub with_user (&@) {
    my ( $code, $uid, @gids ) = @_;
    Test::MockFile->set_user( $uid, @gids );
    my $ok = eval { $code->(); 1 };
    my $err = $@;
    Test::MockFile->clear_user();
    die $err unless $ok;
}

# new_dir applies umask, so we override mode directly after creation
sub make_dir {
    my ( $path, %opts ) = @_;
    my $mode = delete $opts{mode} // 0755;
    my $uid  = delete $opts{uid}  // 0;
    my $gid  = delete $opts{gid}  // 0;
    my $dir  = Test::MockFile->new_dir( $path, {} );
    $dir->{'mode'} = $mode | S_IFDIR;
    $dir->{'uid'}  = $uid;
    $dir->{'gid'}  = $gid;
    return $dir;
}

# =========================================================================
# unlink in sticky directory
# =========================================================================

subtest 'unlink: sticky bit blocks non-owner deletion' => sub {
    my $dir  = make_dir( '/sticky', mode => 01777, uid => 0, gid => 0 );
    my $file = Test::MockFile->file( '/sticky/owned_by_1000', 'data', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        ok( !unlink('/sticky/owned_by_1000'), 'unlink fails for non-owner in sticky dir' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 2000, 2000;
};

subtest 'unlink: file owner can delete in sticky dir' => sub {
    my $dir  = make_dir( '/sticky_owner', mode => 01777, uid => 0, gid => 0 );
    my $file = Test::MockFile->file( '/sticky_owner/myfile', 'data', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        ok( unlink('/sticky_owner/myfile'), 'file owner can unlink in sticky dir' );
    } 1000, 1000;
};

subtest 'unlink: directory owner can delete in sticky dir' => sub {
    my $dir  = make_dir( '/sticky_dirowner', mode => 01777, uid => 500, gid => 500 );
    my $file = Test::MockFile->file( '/sticky_dirowner/otherfile', 'data', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        ok( unlink('/sticky_dirowner/otherfile'), 'dir owner can unlink in sticky dir' );
    } 500, 500;
};

subtest 'unlink: root bypasses sticky bit' => sub {
    my $dir  = make_dir( '/sticky_root', mode => 01777, uid => 500, gid => 500 );
    my $file = Test::MockFile->file( '/sticky_root/rootfile', 'data', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        ok( unlink('/sticky_root/rootfile'), 'root can unlink in sticky dir' );
    } 0, 0;
};

subtest 'unlink: non-sticky directory allows any writer to delete' => sub {
    my $dir  = make_dir( '/nonsticky', mode => 0777, uid => 0, gid => 0 );
    my $file = Test::MockFile->file( '/nonsticky/anyfile', 'data', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        ok( unlink('/nonsticky/anyfile'), 'any user can unlink in non-sticky writable dir' );
    } 2000, 2000;
};

# =========================================================================
# rmdir in sticky directory
# =========================================================================

subtest 'rmdir: sticky bit blocks non-owner removal' => sub {
    my $parent = make_dir( '/sticky_rmdir', mode => 01777, uid => 0, gid => 0 );
    my $child  = Test::MockFile->new_dir( '/sticky_rmdir/subdir', { mode => 0755, uid => 1000, gid => 1000 } );

    with_user {
        ok( !rmdir('/sticky_rmdir/subdir'), 'rmdir fails for non-owner in sticky dir' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 2000, 2000;
};

subtest 'rmdir: entry owner can remove in sticky parent' => sub {
    my $parent = make_dir( '/sticky_rmdir2', mode => 01777, uid => 0, gid => 0 );
    my $child  = Test::MockFile->new_dir( '/sticky_rmdir2/subdir', { mode => 0755, uid => 1000, gid => 1000 } );

    with_user {
        ok( rmdir('/sticky_rmdir2/subdir'), 'entry owner can rmdir in sticky dir' );
    } 1000, 1000;
};

# =========================================================================
# rename in sticky directory
# =========================================================================

subtest 'rename: sticky bit blocks non-owner rename (source)' => sub {
    my $dir = make_dir( '/sticky_ren', mode => 01777, uid => 0, gid => 0 );
    my $src = Test::MockFile->file( '/sticky_ren/src', 'data', { mode => 0644, uid => 1000, gid => 1000 } );
    my $dst = Test::MockFile->file( '/sticky_ren/dst', undef );

    with_user {
        ok( !rename( '/sticky_ren/src', '/sticky_ren/dst' ), 'rename fails for non-owner in sticky dir' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 2000, 2000;
};

subtest 'rename: file owner can rename in sticky dir' => sub {
    my $dir = make_dir( '/sticky_ren2', mode => 01777, uid => 0, gid => 0 );
    my $src = Test::MockFile->file( '/sticky_ren2/src', 'data', { mode => 0644, uid => 1000, gid => 1000 } );
    my $dst = Test::MockFile->file( '/sticky_ren2/dst', undef );

    with_user {
        ok( rename( '/sticky_ren2/src', '/sticky_ren2/dst' ), 'file owner can rename in sticky dir' );
    } 1000, 1000;
};

subtest 'rename: sticky bit on destination blocks overwrite by non-owner' => sub {
    my $srcdir = make_dir( '/ren_src', mode => 0777, uid => 0, gid => 0 );
    my $dstdir = make_dir( '/ren_dst', mode => 01777, uid => 0, gid => 0 );
    my $src = Test::MockFile->file( '/ren_src/file', 'new', { mode => 0644, uid => 2000, gid => 2000 } );
    my $dst = Test::MockFile->file( '/ren_dst/file', 'old', { mode => 0644, uid => 1000, gid => 1000 } );

    with_user {
        ok( !rename( '/ren_src/file', '/ren_dst/file' ), 'rename blocked by sticky bit on destination dir' );
        is( $! + 0, EACCES, 'errno is EACCES' );
    } 2000, 2000;
};

subtest 'rename: root bypasses sticky bit' => sub {
    my $dir = make_dir( '/sticky_ren3', mode => 01777, uid => 500, gid => 500 );
    my $src = Test::MockFile->file( '/sticky_ren3/src', 'data', { mode => 0644, uid => 1000, gid => 1000 } );
    my $dst = Test::MockFile->file( '/sticky_ren3/dst', undef );

    with_user {
        ok( rename( '/sticky_ren3/src', '/sticky_ren3/dst' ), 'root can rename in sticky dir' );
    } 0, 0;
};

done_testing();
