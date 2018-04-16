# -*- perl -*-
# t/002-dircopy.t - tests of dircopy() method
use strict;
use warnings;

use Test::More qw(no_plan); # tests => 16;
use File::Copy::Recursive::Reduced qw(dircopy);

use Capture::Tiny qw(capture_stdout capture_stderr);
use File::Path qw(mkpath);
use File::Spec;
use File::Temp qw(tempfile tempdir);
use Path::Tiny;
use lib qw( t/lib );
use MockHomeDir;
use Helper ( qw|
    create_tfile
    create_tfile_and_name_for_new_file_in_same_dir
    create_tsubdir
| );
    #get_mode
    #get_fresh_tmp_dir

my ($from, $to, $rv);

# bad args #

$rv = dircopy();
ok(! defined $rv, "dircopy() returned undef when not provided correct number of arguments");

$rv = dircopy('foo');
ok(! defined $rv, "dircopy() returned undef when not provided correct number of arguments");

$rv = dircopy('foo', 'bar', 'baz', 'bletch');
ok(! defined $rv, "dircopy() returned undef when not provided correct number of arguments");

$rv = dircopy(undef, 'foo');
ok(! defined $rv, "dircopy() returned undef when first argument was undefined");

$rv = dircopy('foo', undef);
ok(! defined $rv, "dircopy() returned undef when second argument was undefined");

$rv = dircopy('foo', 'foo');
ok(! defined $rv, "dircopy() returned undef when provided 2 identical arguments");

SKIP: {
    skip "System does not support hard links", 3
        unless $File::Copy::Recursive::Reduced::Link;
    my $tdir = tempdir( CLEANUP => 1 );
    my ($old, $new) = create_tfile_and_name_for_new_file_in_same_dir($tdir);
    my $rv = link($old, $new) or die "Unable to link: $!";
    ok($rv, "Able to hard link $old and $new");
    my $stderr = capture_stderr { $rv = dircopy($old, $new); };
    ok(! defined $rv,
        "dircopy() returned undef when provided arguments with identical dev and ino");
    SKIP: {
        skip 'identical-dev-ino check not applicable on Windows', 1
            if ($^O eq 'MSWin32') ;
        like($stderr, qr/\Q$old and $new are identical\E/,
            "dircopy(): got expected warning when provided arguments with identical dev and ino");
    }
}

{
    my $tdir = tempdir(CLEANUP => 1);
    my $tdir2 = tempdir(CLEANUP => 1);
    my $f1 = create_tfile($tdir, 'foo');
    my $f2 = create_tfile($tdir, 'bar');

    $from = $tdir;
    $to = $tdir2;
    $rv = dircopy($from, $to);
    ok(defined $rv, "dircopy() returned defined value");

    $from = "$tdir/*";
    $to = $tdir2;
    $rv = dircopy($from, $to);
    ok(defined $rv, "dircopy() returned defined value when first argument ends with '/*'");
}
