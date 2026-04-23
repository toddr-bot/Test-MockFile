#!/usr/bin/perl -w

# Test for GitHub issue #179: "Spooky action-at-a-distance"
#
# File check operators (-S, -f, etc.) on real (unmocked) filehandles should
# not retain references that prevent garbage collection. A leaked reference
# to a socket filehandle can keep the fd open, causing reads on the other
# end of a socketpair to hang waiting for EOF.
#
# Root cause: Overload::FileCheck's _check() function stores the file/handle
# argument in a lexical $_last_call_for variable (FileCheck.pm line 587)
# after every file check operation. When the argument is a filehandle ref,
# this prevents garbage collection.
#
# The fix must come from Overload::FileCheck (either weaken the ref or
# only cache string filenames). Until then, these tests document the
# expected behavior as TODO.

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;

use Scalar::Util qw(weaken);
use Socket;

use Test::MockFile qw< nostrict >;

# Check if the installed Overload::FileCheck has the ref-leak fix.
# If it does, the TODO tests will pass and Test2 will report them as
# unexpected successes — a signal to remove the TODO blocks.
my $has_ref_leak_fix = do {
    my $weak;
    {
        open my $fh, '<', '/dev/null' or die "Cannot open /dev/null: $!";
        $weak = $fh;
        weaken($weak);
        no warnings;
        -f $fh;
    }
    !defined $weak;
};

# Test 1: Filehandle passed to -f is not retained
{
    my $weak_ref;

    {
        open my $fh, '<', '/dev/null' or die "Cannot open /dev/null: $!";
        $weak_ref = $fh;
        weaken($weak_ref);

        ok( defined $weak_ref, "weak ref is defined before scope exit" );

        no warnings;
        -f $fh;
    }

    todo "Overload::FileCheck caches filehandle refs in \$_last_call_for (needs upstream fix)" => sub {
        ok( !defined $weak_ref, "filehandle is garbage collected after -f (GH #179)" );
    } if !$has_ref_leak_fix;

    ok( !defined $weak_ref, "filehandle is garbage collected after -f (GH #179)" )
        if $has_ref_leak_fix;
}

# Test 2: Socket filehandle passed to -S is not retained
{
    my $weak_ref;

    {
        open my $fh, '<', '/dev/null' or die "Cannot open /dev/null: $!";
        $weak_ref = $fh;
        weaken($weak_ref);

        no warnings;
        -S $fh;
    }

    todo "Overload::FileCheck caches filehandle refs in \$_last_call_for (needs upstream fix)" => sub {
        ok( !defined $weak_ref, "filehandle is garbage collected after -S (GH #179)" );
    } if !$has_ref_leak_fix;

    ok( !defined $weak_ref, "filehandle is garbage collected after -S (GH #179)" )
        if $has_ref_leak_fix;
}

# Test 3: The exact scenario from GH #179 — socketpair with dup'd fd
# This would hang without the fix because the dup'd write handle stays open.
{
    socketpair my $r, my $w, AF_UNIX, SOCK_STREAM, 0
        or die "socketpair: $!";

    my $pid = fork();
    die "fork: $!" unless defined $pid;

    if ( $pid == 0 ) {
        # Child: reproduce the bug scenario with a timeout
        $SIG{ALRM} = sub { exit 1 };    # exit 1 = hung (bug present)
        alarm(5);

        my $fd = fileno $w;
        do {
            open my $w2, "<&=", $fd;
            -S $w2;
        };

        close $w;
        my $line = <$r>;    # Should get EOF immediately if $w2 was freed
        exit 0;             # exit 0 = success (no hang)
    }

    close $w;
    waitpid $pid, 0;
    my $exit = $? >> 8;

    todo "Overload::FileCheck caches filehandle refs in \$_last_call_for (needs upstream fix)" => sub {
        is( $exit, 0, "socketpair read does not hang after -S on dup'd filehandle (GH #179)" );
    } if !$has_ref_leak_fix;

    is( $exit, 0, "socketpair read does not hang after -S on dup'd filehandle (GH #179)" )
        if $has_ref_leak_fix;
}

done_testing;
