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
    note("First argument not a directory or second argument exists already and is not a directory");
    my ($tdir, $old, $new, $rv);
    $tdir = tempdir( CLEANUP => 1 );
    $old = create_tfile($tdir);
    $new = 'foo';
    $rv = dircopy($old, $new);
    ok(! defined $rv, "dircopy() returned undef when first argument was not a directory");
    cmp_ok($!, '>=', 0, "\$ERRNO set: " . $!);
    undef $!;
    ok(! $!, "\$ERRORNO has been cleared");

    $old = create_tsubdir($tdir);
    $new = create_tfile($tdir, 'new');
    $rv = dircopy($old, $new);
    ok(! defined $rv,
        "dircopy() returned undef when second argument -- not a directory -- already existed");
    cmp_ok($!, '>=', 0, "\$ERRNO set: " . $!);
    undef $!;
}



## good args #

my @dirnames = ( qw|
    able baker camera dogtag elmore
    fargo golfer hatrack impish jolt
    karma lily mandate namesake oleo
    partner quorum robot sterling tamarack
    ultra victor windy xray yellow zebra
| );

sub basic_tests {
    my @dirnames = @_;
    {
        note("Multiple directories; no files");
        my ($tdir, $tdir2, $old, $oldtree, $new, $rv, $expected);
        my (@created);
        my @subdirs = @dirnames[0..4];
    
        # Prepare left side
        $tdir   = tempdir( CLEANUP => 1 );
        $old        = File::Spec->catdir($tdir);
        $oldtree    = File::Spec->catdir($tdir, @subdirs);
        @created = mkpath($oldtree, { mode => 0711 });
        die "Unable to create directory $oldtree for testing: $!" unless -d $oldtree;
        ok(-d $oldtree, "Created original directory tree for testing");
    
        # Prepare right side
        $tdir2  = File::Spec->catdir($tdir, 'new_dir');
        $expected   = File::Spec->catdir($tdir2, @subdirs);
    
        # Test
        print STDOUT "AAA: 1st: $old\n";
        print STDOUT "     2nd: $tdir2\n";
        $rv = dircopy($old, $tdir2);
        ok($rv, "dircopy() returned true value");
        ok(-d $tdir2, "dircopy(): directory $tdir2 created");
        ok(-d File::Spec->catdir($tdir2, @subdirs[0..4]), "dircopy(): directory XXXXXX created");
        ok(-d $expected, "dircopy(): directory $expected created");
    }

#    {
#        note("Multiple directories; files at bottom level");
#        my ($tdir, $tdir2, $old, $oldtree, $new, $rv, $expected);
#        my (@created, @basenames);
#        my @subdirs = @dirnames[5..7];
#    
#        # Prepare left side
#        $tdir   = tempdir( CLEANUP => 1 );
#        $old        = File::Spec->catdir($tdir);
#        $oldtree    = File::Spec->catdir($tdir, @subdirs);
#        @created = mkpath($oldtree, { mode => 0711 });
#        die "Unable to create directory $oldtree for testing: $!" unless -d $oldtree;
#        ok(-d $oldtree, "Created $oldtree for testing");
#        @basenames = qw| foo bar |;
#        for my $b (@basenames) {
#            my $f = touch_a_file_and_test(File::Spec->catfile($oldtree, $b));
#        }
#    
#        # Prepare right side
#        $tdir2  = File::Spec->catdir($tdir, 'new_dir');
#        $expected   = File::Spec->catdir($tdir2, @subdirs);
#    
#        # Test
#        print STDOUT "BBB: 1st: $old\n";
#        print STDOUT "     2nd: $tdir2\n";
#        $rv = dircopy($old, $tdir2);
#        ok($rv, "dircopy() returned true value");
#        ok(-d $expected, "dircopy(): directory $expected created");
#        # test for creation of files
#        for my $b (@basenames) {
#            my $f = File::Spec->catfile($expected, $b);
#            ok(-f $f, "dircopy(): file $f created");
#        }
#    }
#
#    {
#        note("Multiple directories; files at intermediate levels");
#        my ($tdir, $tdir2, $old, $oldtree, $new, $rv, $expected);
#        my (@created);
#        my @subdirs = @dirnames[8..11];
#    
#        # Prepare left side
#        $tdir   = tempdir( CLEANUP => 1 );
#        $old        = File::Spec->catdir($tdir);
#        $oldtree    = File::Spec->catdir($tdir, @subdirs);
#        @created = mkpath($oldtree, { mode => 0711 });
#        die "Unable to create directory $oldtree for testing: $!" unless -d $oldtree;
#        ok(-d $oldtree, "Created $oldtree for testing");
#        my $f = File::Spec->catfile(@subdirs[0..1], 'foo');
#        my $g = File::Spec->catfile(@subdirs[0..2], 'bar');
#        my $ff = touch_a_file_and_test(File::Spec->catfile($old, $f));
#        my $gg = touch_a_file_and_test(File::Spec->catfile($old, $f));
#    
#        # Prepare right side
#        $tdir2  = File::Spec->catdir($tdir, 'new_dir');
#        $expected   = File::Spec->catdir($tdir2, @subdirs);
#    
#        # Test
#        print STDOUT "CCC: 1st: $old\n";
#        print STDOUT "     2nd: $tdir2\n";
#        $rv = dircopy($old, $tdir2);
#        ok($rv, "dircopy() returned true value");
#        ok(-d $expected, "dircopy(): directory $expected created");
#        # test for creation of files
#        for my $b ($ff, $gg) {
#            my $c = File::Spec->catfile($expected, $b);
#            ok(-f $c, "dircopy(): file $c created");
#        }
#    }
} # END definition of basic_tests()

sub touch_a_file_and_test {
    my $f = shift;
    open my $OUT, '>', $f or die "Unable to open $f for writing";
    print $OUT "\n";
    close $OUT or die "Unable to close $f after writing";
    ok(-f $f, "Created $f for testing");
    return $f;
}

{
    note("Basic tests of File::Copy::Recursive::Reduced::dircopy()");
    basic_tests(@dirnames);
}

#{
#    note("Basic tests of File::Copy::Recursive::dircopy()");
#    require File::Copy::Recursive;
#    no warnings ('redefine');
#    local *dircopy = \&File::Copy::Recursive::dircopy;
#    use warnings;
#    basic_tests(@dirnames);
#}
__END__

#SKIP: {
#    skip 'mode preservation apparently not significant on Windows', 5
#        if ($^O eq 'MSWin32') ;
#
#    note("Test mode preservation turned off");
#    my $self = File::Copy::Recursive::Reduced->new({ KeepMode => 0 });
#    ok(! {KeepMode}, "new(): KeepMode is turned off");
#    my $tdir = tempdir( CLEANUP => 1 );
#    my ($old, $new) = create_tfile_and_new_path($tdir);
    create_tfile_and_name_for_new_file_in_same_dir
#    my $cnt = chmod 0700, $old;
#    ok($cnt, "chmod on $old");
#    my $old_mode = get_mode($old);
#    my $rv = fcopy($old, $new);
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
#    ok({KeepMode}, "new(): KeepMode is on");
#    my $tdir = tempdir( CLEANUP => 1 );
#    my ($old, $new) = create_tfile_and_new_path($tdir);
    create_tfile_and_name_for_new_file_in_same_dir
#    my $cnt = chmod 0700, $old;
#    ok($cnt, "chmod on $old");
#    my $old_mode = get_mode($old);
#    my $rv = fcopy($old, $new);
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
    create_tfile_and_name_for_new_file_in_same_dir
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
    create_tfile_and_name_for_new_file_in_same_dir
#    my @rvs = fcopy($old, $new);
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
#    eval { $rv = fcopy($old, $new, $buffer); };
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
#    $stderr = capture_stderr { $rv = fcopy($old, $new, $buffer); };
#    ok($rv, "fcopy(): Providing buffer as third argument at least does not die");
#    like($stderr, qr/^from:.*?to:.*?buf:/, "fcopy(): got plausible debugging output");
#    ok(-f $new, "$new created");
#}
#
#SKIP: {
#    skip 'symlinks not available on this platform', 4
#        unless {CopyLink};
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
#    $rv = fcopy($symlink, $new);
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
#    $stderr = capture_stderr { $rv = fcopy($xsymlink, $xnew); };
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
#    $rv = fcopy( "$tmpd/orig/data", "$tmpd/fcopy" );
#    is(
#        path("$tmpd/orig/data")->slurp,
#        path("$tmpd/fcopy")->slurp,
#        "fcopy() defaults as expected when target does not exist"
#    );
#
#    path("$tmpd/fcopyexisty")->spew("oh hai");
#    my @fcopy_rv = fcopy( "$tmpd/orig/data", "$tmpd/fcopyexisty");
#    is(
#        path("$tmpd/orig/data")->slurp,
#        path("$tmpd/fcopyexisty")->slurp,
#        "fcopy() defaults as expected when target does exist"
#    );
#
#    # This is the test that fails on FreeBSD
#    # https://rt.cpan.org/Ticket/Display.html?id=123964
#    $rv = fcopy( "$tmpd/orig", "$tmpd/fcopy" );
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
#        fcopy($sample_history_file, $history_file);
#        ok( -f $history_file, "copied sample old history file to config directory");
#    }
#}

__END__

#    cmp_ok($new_mode, 'eq', $old_mode, "fcopy(): mode preserved: $old_mode to $new_mode");
