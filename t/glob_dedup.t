use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test::MockFile;

# Test that glob() does not return duplicate entries for directories
# that appear both as explicit mocks and as derived parent paths
# of mocked files.

# Setup: a mocked directory with two files inside it
my $dir  = Test::MockFile->dir("/duptest");
my $file1 = Test::MockFile->file("/duptest/a.txt", "hello");
my $file2 = Test::MockFile->file("/duptest/b.txt", "world");

# Bug: __glob builds a candidate list by taking all mocked paths that
# exist AND adding their parent directories.  When a directory is both
# explicitly mocked and is the parent of N mocked files, it appears
# N+1 times in the candidate list.  Text::Glob::match_glob preserves
# these duplicates and no deduplication step follows.

# glob for an exact directory name should return it exactly once
is(
    [ glob("/duptest") ],
    ["/duptest"],
    'glob("/duptest") returns exactly one result, not duplicates',
);

# glob with a wildcard matching the directory should also be unique
is(
    [ glob("/dup*") ],
    ["/duptest"],
    'glob("/dup*") returns exactly one result, not duplicates',
);

# Sanity: children should be listed without duplicates too
is(
    [ glob("/duptest/*") ],
    [ "/duptest/a.txt", "/duptest/b.txt" ],
    'glob("/duptest/*") returns children without duplicates',
);

# Additional case: deeper nesting.  /nest/sub exists as dir, /nest/sub/c
# and /nest/sub/d are files.  The parent /nest/sub is derived from both
# children in addition to being explicitly mocked, so it appears 3 times.
my $nest    = Test::MockFile->dir("/nest");
my $nestsub = Test::MockFile->dir("/nest/sub");
my $nc      = Test::MockFile->file("/nest/sub/c", "x");
my $nd      = Test::MockFile->file("/nest/sub/d", "y");

is(
    [ glob("/nest/*") ],
    ["/nest/sub"],
    'glob("/nest/*") returns only direct children, no duplicates',
);

done_testing();
