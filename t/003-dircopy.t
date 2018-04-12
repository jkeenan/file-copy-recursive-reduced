# -*- perl -*-
# t/003-dircopy.t - tests of dircopy() method
use strict;
use warnings;

use Test::More qw(no_plan); # tests => 16;
use Carp;
use Capture::Tiny qw(capture_stdout capture_stderr);
use File::Path qw(mkpath);
use File::Spec;
use File::Temp qw(tempfile tempdir);
use Path::Tiny;
use lib qw( t/lib );
use MockHomeDir;
use Helper ( qw|
    create_tfile
    create_tfile_and_new_path
    create_tsubdir
| );
    #get_mode
    #get_fresh_tmp_dir

BEGIN { use_ok( 'File::Copy::Recursive::Reduced' ); }

my ($self, $from, $to, $buf, $rv);

$self = File::Copy::Recursive::Reduced->new();

# bad args #

$rv = $self->dircopy();
ok(! defined $rv, "dircopy() returned undef when not provided correct number of arguments");

$rv = $self->dircopy('foo');
ok(! defined $rv, "dircopy() returned undef when not provided correct number of arguments");

$rv = $self->dircopy('foo', 'bar', 'baz', 'bletch');
ok(! defined $rv, "dircopy() returned undef when not provided correct number of arguments");

$rv = $self->dircopy(undef, 'foo');
ok(! defined $rv, "dircopy() returned undef when first argument was undefined");

$rv = $self->dircopy('foo', undef);
ok(! defined $rv, "dircopy() returned undef when second argument was undefined");

$rv = $self->dircopy('foo', 'foo');
ok(! defined $rv, "dircopy() returned undef when provided 2 identical arguments");

if ($self->{Link}) {
    my $self = File::Copy::Recursive::Reduced->new({debug => 1});
    ok($self->{debug}, "new(): debugging on");
    my $tdir = tempdir( CLEANUP => 1 );
    my ($old, $new) = create_tfile_and_new_path($tdir);
    my $rv = link($old, $new) or croak "Unable to link";
    ok($rv, "Able to hard link $old and $new");
    my $stderr = capture_stderr { $rv = $self->dircopy($old, $new); };
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
    note("First argument not a directory or second argument exists already and is not a directory");
    my ($self, $tdir, $old, $new, $rv);
    #my $self = File::Copy::Recursive::Reduced->new({debug => 1});
    $self = File::Copy::Recursive::Reduced->new();
    $tdir = tempdir( CLEANUP => 1 );
    $old = create_tfile($tdir);
    $new = 'foo';
    $rv = $self->dircopy($old, $new);
    ok(! defined $rv, "dircopy() returned undef when first argument was not a directory");
    cmp_ok($!, '>=', 0, "\$ERRNO set: " . $!);
    undef $!;
    ok(! $!, "\$ERRORNO has been cleared");

    $old = create_tsubdir($tdir);
    $new = create_tfile($tdir, 'new');
    $rv = $self->dircopy($old, $new);
    ok(! defined $rv,
        "dircopy() returned undef when second argument -- not a directory -- already existed");
    cmp_ok($!, '>=', 0, "\$ERRNO set: " . $!);
    undef $!;
}


## good args #
#
#{
#    note("Basic test of fcopy()");
#    my $self = File::Copy::Recursive::Reduced->new({debug => 1});
#    my $tdir = tempdir( CLEANUP => 1 );
#    my ($old, $new) = create_tfile_and_new_path($tdir);
#    my ($rv, $stderr);
#    my $old_mode = get_mode($old);
#    $stderr = capture_stderr { $rv = $self->fcopy($old, $new); };
#    ok($rv, "fcopy() returned true value");
#    like($stderr, qr/^from:.*?to:/, "fcopy(): got plausible debugging output");
#    ok(-f $new, "$new created");
#    my $new_mode = get_mode($new);
#    cmp_ok($new_mode, 'eq', $old_mode, "fcopy(): mode preserved: $old_mode to $new_mode");
#}
#
#SKIP: {
#    skip 'mode preservation apparently not significant on Windows', 5
#        if ($^O eq 'MSWin32') ;
#
#    note("Test mode preservation turned off");
#    my $self = File::Copy::Recursive::Reduced->new({ KeepMode => 0 });
#    ok(! $self->{KeepMode}, "new(): KeepMode is turned off");
#    my $tdir = tempdir( CLEANUP => 1 );
#    my ($old, $new) = create_tfile_and_new_path($tdir);
#    my $cnt = chmod 0700, $old;
#    ok($cnt, "chmod on $old");
#    my $old_mode = get_mode($old);
#    my $rv = $self->fcopy($old, $new);
#    ok($rv, "fcopy() returned true value");
#    ok(-f $new, "$new created");
#    my $new_mode = get_mode($new);
#    cmp_ok($new_mode, 'ne', $old_mode,
#        "fcopy(): With KeepMode turned off, mode not preserved from $old_mode to $new_mode");
#}
#
#{
#    note("Test default mode preservation");
#    my $self = File::Copy::Recursive::Reduced->new({});
#    ok($self->{KeepMode}, "new(): KeepMode is on");
#    my $tdir = tempdir( CLEANUP => 1 );
#    my ($old, $new) = create_tfile_and_new_path($tdir);
#    my $cnt = chmod 0700, $old;
#    ok($cnt, "chmod on $old");
#    my $old_mode = get_mode($old);
#    my $rv = $self->fcopy($old, $new);
#    ok($rv, "fcopy() returned true value");
#    ok(-f $new, "$new created");
#    my $new_mode = get_mode($new);
#    cmp_ok($new_mode, 'eq', $old_mode,
#        "fcopy(): With KeepMode on, mode preserved from $old_mode to $new_mode");
#}
#
#{
#    note("Test whether method chaining works");
#    my $tdir = tempdir( CLEANUP => 1 );
#    my ($old, $new) = create_tfile_and_new_path($tdir);
#    my $cnt = chmod 0700, $old;
#    ok($cnt, "chmod on $old");
#    my $old_mode = get_mode($old);
#
#    my $rv;
#    ok($rv = File::Copy::Recursive::Reduced->new({})->fcopy($old, $new),
#        "new() and fcopy() returned true value when chained");
#    ok(-f $new, "$new created");
#    my $new_mode = get_mode($new);
#    cmp_ok($new_mode, 'eq', $old_mode,
#        "fcopy(): With KeepMode on, mode preserved from $old_mode to $new_mode");
#}
#
#{
#    note("Test calling fcopy() in list context");
#    my $self = File::Copy::Recursive::Reduced->new();
#    my $tdir = tempdir( CLEANUP => 1 );
#    my ($old, $new) = create_tfile_and_new_path($tdir);
#    my @rvs = $self->fcopy($old, $new);
#    is_deeply( [ @rvs ], [ 1, 0, 0 ],
#        "fcopy(): Got expected return values in list context");
#    ok(-f $new, "$new created");
#}
#
#{
#    note("Test calling fcopy() with buffer-size third argument");
#    my $self = File::Copy::Recursive::Reduced->new();
#    my $tdir = tempdir( CLEANUP => 1 );
#    my $old = create_tfile($tdir);
#    my $newpath = File::Spec->catdir($tdir, 'newpath');
#    my $new = File::Spec->catfile($newpath, 'new');
#    my $buffer = (1024 * 1024 * 2) + 1;
#    my $rv;
#    eval { $rv = $self->fcopy($old, $new, $buffer); };
#    ok($rv, "fcopy(): Providing buffer as third argument at least does not die");
#    ok(-f $new, "$new created");
#}
#
#{
#    note("Test calling fcopy() with buffer-size third argument with debug");
#    my $self = File::Copy::Recursive::Reduced->new({ debug => 1 });
#    my $tdir = tempdir( CLEANUP => 1 );
#    my $old = create_tfile($tdir);
#    my $newpath = File::Spec->catdir($tdir, 'newpath');
#    my $new = File::Spec->catfile($newpath, 'new');
#    my $buffer = (1024 * 1024 * 2) + 1;
#    my ($rv, $stderr);
#    $stderr = capture_stderr { $rv = $self->fcopy($old, $new, $buffer); };
#    ok($rv, "fcopy(): Providing buffer as third argument at least does not die");
#    like($stderr, qr/^from:.*?to:.*?buf:/, "fcopy(): got plausible debugging output");
#    ok(-f $new, "$new created");
#}
#
#SKIP: {
#    skip 'symlinks not available on this platform', 4
#        unless $self->{CopyLink};
#
#    note("Test calling fcopy() on symlinks");
#    my ($self, $tdir, $old, $new, $symlink, $rv);
#    $self = File::Copy::Recursive::Reduced->new();
#    $tdir = tempdir( CLEANUP => 1 );
#    $old = create_tfile($tdir);
#    $symlink = File::Spec->catfile($tdir, 'sym');
#    $rv = symlink($old, $symlink)
#        or croak "Unable to symlink $symlink to target $old for testing";
#    ok(-l $symlink, "fcopy(): $symlink is indeed a symlink");
#    $new = File::Spec->catfile($tdir, 'new');
#    $rv = $self->fcopy($symlink, $new);
#    ok($rv, "fcopy() returned true value when copying from symlink");
#    ok(-f $new, "fcopy(): $new is a file");
#    ok(-l $new, "fcopy(): but $new is also another symlink");
#
#    my ($xold, $xnew, $xsymlink, $stderr);
#    $xold = create_tfile($tdir);
#    $xsymlink = File::Spec->catfile($tdir, 'xsym');
#    $rv = symlink($xold, $xsymlink)
#        or croak "Unable to symlink $xsymlink to target $xold for testing";
#    ok(-l $xsymlink, "fcopy(): $xsymlink is indeed a symlink");
#    $xnew = File::Spec->catfile($tdir, 'xnew');
#    unlink $xold or croak "Unable to unlink $xold during testing";
#    $stderr = capture_stderr { $rv = $self->fcopy($xsymlink, $xnew); };
#    ok($rv, "fcopy() returned true value when copying from symlink");
#    like($stderr, qr/Copying a symlink \($xsymlink\) whose target does not exist/,
#        "fcopy(): Got expected warning when copying from symlink whose target does not exist");
#
#}
#
#{
#    note("Tests from FCR t/01.legacy.t");
#    my ($self, $tdir, $old, $new, $symlink, $rv);
#    $self = File::Copy::Recursive::Reduced->new();
#    my $tmpd = get_fresh_tmp_dir($self);
#    ok(-d $tmpd, "$tmpd exists");
#
#    # that fcopy copies files and symlinks is covered by the dircopy tests, specifically _is_deeply_path()
#    $rv = $self->fcopy( "$tmpd/orig/data", "$tmpd/fcopy" );
#    is(
#        path("$tmpd/orig/data")->slurp,
#        path("$tmpd/fcopy")->slurp,
#        "fcopy() defaults as expected when target does not exist"
#    );
#
#    path("$tmpd/fcopyexisty")->spew("oh hai");
#    my @fcopy_rv = $self->fcopy( "$tmpd/orig/data", "$tmpd/fcopyexisty");
#    is(
#        path("$tmpd/orig/data")->slurp,
#        path("$tmpd/fcopyexisty")->slurp,
#        "fcopy() defaults as expected when target does exist"
#    );
#
#    # This is the test that fails on FreeBSD
#    # https://rt.cpan.org/Ticket/Display.html?id=123964
#    $rv = $self->fcopy( "$tmpd/orig", "$tmpd/fcopy" );
#    ok(!$rv, "RTC 123964: fcopy() returns false if source is a directory");
#}
#
#{
#    note("Tests using FCR's fcopy() from CPAN::Reporter's test suite");
#    # t/66_have_tested.t
#    # t/72_rename_history.t
#    my $config_dir = File::Spec->catdir( MockHomeDir::home_dir, ".cpanreporter" );
#    my $config_file = File::Spec->catfile( $config_dir, "config.ini" );
#    my $history_file = File::Spec->catfile( $config_dir, "reports-sent.db" );
#    my $sample_history_file = File::Spec->catfile(qw/t history reports-sent-longer.db/); 
#    mkpath( $config_dir );
#    ok( -d $config_dir, "temporary config dir created" );
#    
#    # CPAN::Reporter:If old history exists, convert it
#    # I'm not really sure what the point of this test is.
#    SKIP: {
#        skip "$sample_history_file does not exist", 1
#            unless -e $sample_history_file;
#        my $self = File::Copy::Recursive::Reduced->new({ debug => 1 });
#        $self->fcopy($sample_history_file, $history_file);
#        ok( -f $history_file, "copied sample old history file to config directory");
#    }
#}

