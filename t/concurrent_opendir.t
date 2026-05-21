#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;

use Test::MockFile qw< nostrict >;

note "-------------- concurrent opendir: independent iteration state --------------";
{
    my $dir = Test::MockFile->new_dir( '/cdir', { 'autovivify' => 1 } );

    open my $fh, '>', '/cdir/aaa' or die;
    close $fh;
    open $fh, '>', '/cdir/bbb' or die;
    close $fh;

    opendir my $dh1, '/cdir' or die "opendir1: $!";
    my $first1 = readdir($dh1);
    is( $first1, '.', 'dh1 reads . first' );

    opendir my $dh2, '/cdir' or die "opendir2: $!";
    my $first2 = readdir($dh2);
    is( $first2, '.', 'dh2 reads . first' );

    my $second1 = readdir($dh1);
    is( $second1, '..', 'dh1 reads .. second (not clobbered by dh2)' );

    my $second2 = readdir($dh2);
    is( $second2, '..', 'dh2 reads .. second' );

    my @rest1 = readdir($dh1);
    my @rest2 = readdir($dh2);
    is( \@rest1, [qw/aaa bbb/], 'dh1 reads remaining files' );
    is( \@rest2, [qw/aaa bbb/], 'dh2 reads remaining files independently' );

    closedir $dh1;
    closedir $dh2;
}

note "-------------- concurrent opendir: close one, other continues --------------";
{
    my $dir = Test::MockFile->new_dir('/cdir2');

    opendir my $dh1, '/cdir2' or die;
    opendir my $dh2, '/cdir2' or die;

    readdir($dh1);    # .
    closedir $dh1;

    my @entries = readdir($dh2);
    is( \@entries, [ '.', '..' ], 'dh2 still has full iteration after dh1 is closed' );

    closedir $dh2;
}

note "-------------- concurrent opendir: telldir/seekdir per handle --------------";
{
    my $dir = Test::MockFile->new_dir( '/cdir3', { 'autovivify' => 1 } );

    open my $fh, '>', '/cdir3/x' or die;
    close $fh;

    opendir my $dh1, '/cdir3' or die;
    opendir my $dh2, '/cdir3' or die;

    readdir($dh1);    # .
    readdir($dh1);    # ..

    is( telldir($dh1), 2, 'dh1 tell is 2 after reading two entries' );
    is( telldir($dh2), 0, 'dh2 tell is still 0' );

    seekdir( $dh1, 0 );
    is( scalar readdir($dh1), '.', 'dh1 seeked back to start' );

    is( scalar readdir($dh2), '.', 'dh2 unaffected by dh1 seek' );

    closedir $dh1;
    closedir $dh2;
}

note "-------------- concurrent opendir: rewinddir per handle --------------";
{
    my $dir = Test::MockFile->new_dir('/cdir4');

    opendir my $dh1, '/cdir4' or die;
    opendir my $dh2, '/cdir4' or die;

    readdir($dh1);    # .
    readdir($dh1);    # ..
    rewinddir($dh1);

    is( telldir($dh1), 0, 'dh1 rewound to 0' );
    is( telldir($dh2), 0, 'dh2 still at 0 (unaffected)' );
    is( scalar readdir($dh1), '.', 'dh1 reads . after rewind' );

    closedir $dh1;
    closedir $dh2;
}

note "-------------- concurrent opendir: double close warns --------------";
{
    my $dir = Test::MockFile->new_dir('/cdir5');

    opendir my $dh, '/cdir5' or die;
    closedir $dh;

    my @w;
    {
        local $SIG{__WARN__} = sub { push @w, $_[0] };
        closedir $dh;
    }

    ok( @w == 1 && $w[0] =~ /closedir\(\) attempted on invalid dirhandle/, 'double close warns' );
}

done_testing;
