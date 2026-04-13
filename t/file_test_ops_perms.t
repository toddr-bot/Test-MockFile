#!perl

# Test that -r/-w/-x/-o/-R/-W/-X/-O respect set_user() mock permissions.
# Without the fix, these operators always use the real process uid/gid,
# ignoring set_user() entirely.

use strict;
use warnings;

use Test::More;
use Test::MockFile;

# Helper: create a file and override its mode directly (bypass umask).
sub mock_file_with_mode {
    my ( $path, $contents, %opts ) = @_;
    my $mock = Test::MockFile->file( $path, $contents, \%opts );
    # Override mode directly to avoid umask stripping bits.
    if ( exists $opts{mode} ) {
        my @s = stat($path);
        # Preserve file-type bits, replace permission bits.
        $mock->{'mode'} = ( $s[2] & ~07777 ) | ( $opts{mode} & 07777 );
    }
    return $mock;
}

# Helper to run a block under a specific mock user.
sub with_user (&@) {
    my ( $code, $uid, @gids ) = @_;
    Test::MockFile->set_user( $uid, @gids );
    $code->();
    Test::MockFile->clear_user();
}

subtest 'owner access on 0600 file' => sub {
    my $f = mock_file_with_mode( '/perms/owner_rw', 'data', mode => 0600, uid => 1000, gid => 1000 );

    with_user {
        ok( -r '/perms/owner_rw', '-r true for owner' );
        ok( -w '/perms/owner_rw', '-w true for owner' );
        ok( !-x '/perms/owner_rw', '-x false (no x bit)' );
        ok( -o '/perms/owner_rw', '-o true for owner' );
    } 1000, 1000;

    with_user {
        ok( !-r '/perms/owner_rw', '-r false for non-owner' );
        ok( !-w '/perms/owner_rw', '-w false for non-owner' );
        ok( !-o '/perms/owner_rw', '-o false for non-owner' );
    } 2000, 2000;
};

subtest 'group access on 0070 file' => sub {
    my $f = mock_file_with_mode( '/perms/group_rwx', 'data', mode => 0070, uid => 1000, gid => 500 );

    # Group member
    with_user {
        ok( -r '/perms/group_rwx', '-r true for group member' );
        ok( -w '/perms/group_rwx', '-w true for group member' );
        ok( -x '/perms/group_rwx', '-x true for group member' );
        ok( !-o '/perms/group_rwx', '-o false (not owner)' );
    } 2000, 500;

    # Non-group non-owner
    with_user {
        ok( !-r '/perms/group_rwx', '-r false for other' );
        ok( !-w '/perms/group_rwx', '-w false for other' );
        ok( !-x '/perms/group_rwx', '-x false for other' );
    } 3000, 3000;
};

subtest 'other access on 0005 file' => sub {
    my $f = mock_file_with_mode( '/perms/other_rx', 'data', mode => 0005, uid => 1000, gid => 1000 );

    with_user {
        ok( -r '/perms/other_rx', '-r true for other with r bit' );
        ok( !-w '/perms/other_rx', '-w false for other (no w bit)' );
        ok( -x '/perms/other_rx', '-x true for other with x bit' );
    } 2000, 2000;
};

subtest 'root bypass' => sub {
    my $f = mock_file_with_mode( '/perms/root_test', 'data', mode => 0600, uid => 1000, gid => 1000 );

    with_user {
        ok( -r '/perms/root_test', 'root can read any file' );
        ok( -w '/perms/root_test', 'root can write any file' );
        ok( !-x '/perms/root_test', 'root cannot execute without any x bit' );
    } 0, 0;

    # Root with x bit somewhere
    my $f2 = mock_file_with_mode( '/perms/root_exec', 'data', mode => 0610, uid => 1000, gid => 1000 );

    with_user {
        ok( -x '/perms/root_exec', 'root can execute when any x bit is set' );
    } 0, 0;
};

subtest '-R/-W/-X/-O match -r/-w/-x/-o under set_user' => sub {
    my $f = mock_file_with_mode( '/perms/real_eff', 'data', mode => 0750, uid => 1000, gid => 500 );

    with_user {
        ok( -R '/perms/real_eff', '-R true for owner' );
        ok( -W '/perms/real_eff', '-W true for owner' );
        ok( -X '/perms/real_eff', '-X true for owner' );
        ok( -O '/perms/real_eff', '-O true for owner' );
    } 1000, 1000;

    with_user {
        ok( -R '/perms/real_eff', '-R true for group member' );
        ok( !-W '/perms/real_eff', '-W false for group member (0750)' );
        ok( -X '/perms/real_eff', '-X true for group member' );
        ok( !-O '/perms/real_eff', '-O false for group member' );
    } 2000, 500;
};

subtest 'directory permissions' => sub {
    my $d = Test::MockFile->new_dir( '/perms/dir_test', { mode => 0755, uid => 1000, gid => 1000 } );
    $d->{'mode'} = ( $d->{'mode'} & ~07777 ) | 0755;

    with_user {
        ok( -r '/perms/dir_test', '-r true for dir owner' );
        ok( -w '/perms/dir_test', '-w true for dir owner' );
        ok( -x '/perms/dir_test', '-x true for dir owner' );
    } 1000, 1000;

    with_user {
        ok( -r '/perms/dir_test', '-r true for dir other (0755)' );
        ok( !-w '/perms/dir_test', '-w false for dir other (0755)' );
        ok( -x '/perms/dir_test', '-x true for dir other (0755)' );
    } 2000, 2000;
};

subtest 'nonexistent file returns false' => sub {
    my $f = Test::MockFile->file('/perms/nonexistent');

    with_user {
        ok( !-r '/perms/nonexistent', '-r false for nonexistent file' );
        ok( !-w '/perms/nonexistent', '-w false for nonexistent file' );
        ok( !-x '/perms/nonexistent', '-x false for nonexistent file' );
        ok( !-o '/perms/nonexistent', '-o false for nonexistent file' );
    } 1000, 1000;
};

subtest 'without set_user, falls back to real behavior' => sub {
    # When no mock user is active, -r/-w/-x should use the real process uid.
    # We just verify the call doesn't crash and returns something boolean.
    my $f = Test::MockFile->file( '/perms/no_user', 'data' );

    my $r = -r '/perms/no_user';
    ok( defined $r, '-r returns a defined value without set_user' );

    my $w = -w '/perms/no_user';
    ok( defined $w, '-w returns a defined value without set_user' );
};

done_testing();
