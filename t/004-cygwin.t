# -*- perl -*-
# t/001-fcopy.t - tests on Cygwin and MSYS2
use strict;
use warnings;

use Capture::Tiny qw(capture capture_stderr);
use Test::More tests => 7;
use File::Copy::Recursive::Reduced qw( fcopy );
use lib qw( t/lib );
use Helper qw(run_system_cmd run_bash_cmd);
use CygwinHelper qw(env_prefix);


SKIP: {
    skip "tests only for msys2 or cygwin", 7 if $^O !~ /^(?:cygwin|msys)$/;
    #  Note that the environment variable MSYS or CYGWIN cannot/should not be changed from within the
    #  perl script itself.
    #
    #  TODO: I am not sure why this does not work, but I tested it and it showed undefined
    #  behavior.
    #
    # So the variables should be set before perl is run, e.g. on the command line:
    #
    #   MSYS=winsymlinks:native perl p.pl
    #
    # Unfortunately, this means that we have to start a new perl perl process for each test.
    test_symlink();
    test_fcopy();
}

sub test_fcopy {
    note("Test if fcopy() works with symlinks on MSYS2 and Cygwin");
    my $prefix = env_prefix("nativestrict");
    my $cmd = "$prefix $^X t/scripts/cygwin/fcopy_broken_symlink.pl";
    my ($stdout, $stderr, $exit) = capture { run_bash_cmd( $cmd) };
    ok( $exit == 0, 'winsymlinks:nativestrict should fail for a broken symlink');
    like($stderr, qr/^\QCannot copy a symlink whose target does not exists on\E/,
            "fcopy(): got expected warning when trying to copy broken symlink");
}

sub test_symlink {
    note("Test if the perl symlink() call works as expected on MSYS2 and Cygwin");
    my $dev_mode;
    {
        my $prefix = env_prefix("nativestrict");
        my $result = run_bash_cmd("$prefix $^X t/scripts/cygwin/create_symlink.pl");
        die "Running external script failed" if $result == 2;
        $dev_mode = $result == 0;
    }
    if (!$dev_mode) {
        note("Windows developer mode is not switched on. Creating native symlinks is not possible..");
    }
    my @tests = (undef, '', 'lnk', 'native', 'nativestrict');
    my @expected;
    if ($^O eq 'msys') {
        if ($dev_mode) {
            @expected = (1, 0, 0, 0, 1);
        }
        else {
            # Note: "native" succeeds since it falls back to "lnk" when developer mode is not on..
            @expected = (1, 0, 0, 0, 1);
        }
    }
    elsif ($^O eq 'cygwin') {
        if ($dev_mode) {
            @expected = (0, 0, 0, 0, 1);
        }
        else {
            # Note: "native" succeeds since it falls back to "lnk" when developer mode is not on..
            @expected = (0, 0, 0, 0, 1);
        }
    }
    for my $idx (0..$#tests) {
        my $mode = $tests[$idx];
        my $prefix = env_prefix($mode);
        ok( run_bash_cmd("$prefix $^X t/scripts/cygwin/create_broken_symlink.pl") == $expected[$idx], )
    }
}

