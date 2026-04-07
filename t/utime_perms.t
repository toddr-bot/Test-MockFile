#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception qw< dies lives >;
use Test::MockFile ();
use Errno qw< EACCES EPERM >;

# Disable umask so mode bits in tests are exact
my $saved_umask = umask(0);
END { umask($saved_umask) if defined $saved_umask }

# utime POSIX permission rules:
#   - Root can always set times
#   - Owner can always set times
#   - Non-owner with write permission can set times to "now" (undef, undef)
#   - Non-owner without write permission gets EACCES

subtest(
    'owner can set arbitrary times' => sub {
        my $file = Test::MockFile->file( '/perm/owner_arb', 'data', { uid => 1000, gid => 1000, mode => 0644 } );

        Test::MockFile->set_user( 1000, 1000 );
        $! = 0;
        is( utime( 5000, 6000, '/perm/owner_arb' ), 1, 'owner can set arbitrary times' );

        my @stat = stat('/perm/owner_arb');
        is( $stat[8], 5000, 'atime set correctly' );
        is( $stat[9], 6000, 'mtime set correctly' );

        Test::MockFile->clear_user();
    }
);

subtest(
    'owner can set times to now' => sub {
        my $file = Test::MockFile->file( '/perm/owner_now', 'data', { uid => 1000, gid => 1000, mode => 0644 } );

        Test::MockFile->set_user( 1000, 1000 );
        my $before = time;
        is( utime( undef, undef, '/perm/owner_now' ), 1, 'owner can set times to now' );
        my $after = time;

        my @stat = stat('/perm/owner_now');
        ok( $stat[8] >= $before && $stat[8] <= $after, 'atime set to current time' );
        ok( $stat[9] >= $before && $stat[9] <= $after, 'mtime set to current time' );

        Test::MockFile->clear_user();
    }
);

subtest(
    'root can set times on any file' => sub {
        my $file = Test::MockFile->file( '/perm/root_any', 'data', { uid => 1000, gid => 1000, mode => 0600 } );

        Test::MockFile->set_user( 0, 0 );
        is( utime( 9000, 9001, '/perm/root_any' ), 1, 'root can set times on any file' );

        my @stat = stat('/perm/root_any');
        is( $stat[8], 9000, 'atime set by root' );
        is( $stat[9], 9001, 'mtime set by root' );

        Test::MockFile->clear_user();
    }
);

subtest(
    'non-owner with write perm can set times to now (undef)' => sub {
        my $file = Test::MockFile->file( '/perm/writer_now', 'data', { uid => 1000, gid => 1000, mode => 0666 } );

        Test::MockFile->set_user( 2000, 2000 );
        my $before = time;
        $! = 0;
        is( utime( undef, undef, '/perm/writer_now' ), 1, 'non-owner with write can set to now' );
        my $after = time;

        my @stat = stat('/perm/writer_now');
        ok( $stat[8] >= $before && $stat[8] <= $after, 'atime set to current time' );
        ok( $stat[9] >= $before && $stat[9] <= $after, 'mtime set to current time' );

        Test::MockFile->clear_user();
    }
);

subtest(
    'non-owner with write perm cannot set arbitrary times' => sub {
        my $file = Test::MockFile->file( '/perm/writer_arb', 'data', { uid => 1000, gid => 1000, mode => 0666 } );

        Test::MockFile->set_user( 2000, 2000 );
        $! = 0;
        is( utime( 5000, 6000, '/perm/writer_arb' ), 0, 'non-owner cannot set arbitrary times' );
        is( $! + 0, EPERM, '$! is EPERM' );

        # Verify times were NOT changed
        my @stat = stat('/perm/writer_arb');
        isnt( $stat[8], 5000, 'atime was not changed' );

        Test::MockFile->clear_user();
    }
);

subtest(
    'non-owner without write perm cannot set times at all' => sub {
        my $file = Test::MockFile->file( '/perm/nowrite', 'data', { uid => 1000, gid => 1000, mode => 0644 } );

        Test::MockFile->set_user( 2000, 2000 );

        # Cannot set arbitrary times
        $! = 0;
        is( utime( 5000, 6000, '/perm/nowrite' ), 0, 'non-owner without write cannot set times' );
        is( $! + 0, EACCES, '$! is EACCES for arbitrary times' );

        # Cannot even set to "now"
        $! = 0;
        is( utime( undef, undef, '/perm/nowrite' ), 0, 'non-owner without write cannot set to now' );
        is( $! + 0, EACCES, '$! is EACCES for undef times too' );

        Test::MockFile->clear_user();
    }
);

subtest(
    'group write permission allows utime to now' => sub {
        my $file = Test::MockFile->file( '/perm/grp_write', 'data', { uid => 1000, gid => 500, mode => 0464 } );

        # User 2000 in group 500 — group has write permission
        Test::MockFile->set_user( 2000, 500 );
        my $before = time;
        $! = 0;
        is( utime( undef, undef, '/perm/grp_write' ), 1, 'group write allows utime to now' );
        my $after = time;

        my @stat = stat('/perm/grp_write');
        ok( $stat[8] >= $before && $stat[8] <= $after, 'atime set to current time' );

        Test::MockFile->clear_user();
    }
);

subtest(
    'multiple files with mixed permissions' => sub {
        my $owned = Test::MockFile->file( '/perm/multi_owned', 'data', { uid => 1000, gid => 1000, mode => 0644 } );
        my $denied = Test::MockFile->file( '/perm/multi_denied', 'data', { uid => 2000, gid => 2000, mode => 0600 } );

        Test::MockFile->set_user( 1000, 1000 );
        $! = 0;
        is( utime( 7000, 8000, '/perm/multi_owned', '/perm/multi_denied' ), 1,
            'utime returns 1 — only owned file succeeded' );

        my @stat_owned = stat('/perm/multi_owned');
        is( $stat_owned[8], 7000, 'owned file atime updated' );

        my @stat_denied = stat('/perm/multi_denied');
        isnt( $stat_denied[8], 7000, 'denied file atime NOT updated' );

        Test::MockFile->clear_user();
    }
);

subtest(
    'no set_user means no permission checks (default)' => sub {
        my $file = Test::MockFile->file( '/perm/nochk', 'data', { uid => 0, gid => 0, mode => 0000 } );

        # Without set_user, permission checks are disabled
        is( utime( 1000, 2000, '/perm/nochk' ), 1, 'utime succeeds without set_user regardless of mode' );

        my @stat = stat('/perm/nochk');
        is( $stat[8], 1000, 'atime set correctly' );
    }
);

done_testing();
exit;
