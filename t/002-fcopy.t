# -*- perl -*-
# t/002-fcopy.t - tests of fcopy() method
use strict;
use warnings;

use Test::More qw(no_plan); # tests =>  2;
use Carp;
use Capture::Tiny qw(capture_stdout capture_stderr);
use File::Path qw(mkpath);
use File::Spec;
use File::Temp qw(tempfile tempdir);
use Path::Tiny;
use lib qw( t/lib );
use MockHomeDir;

BEGIN { use_ok( 'File::Copy::Recursive::Reduced' ); }

my ($self, $from, $to, $buf, $rv);

$self = File::Copy::Recursive::Reduced->new();

# bad args #

$rv = $self->fcopy();
ok(! defined $rv, "fcopy() returned undef when not provided correct number of arguments");

$rv = $self->fcopy('foo');
ok(! defined $rv, "fcopy() returned undef when not provided correct number of arguments");

$rv = $self->fcopy('foo', 'bar', 'baz', 'bletch');
ok(! defined $rv, "fcopy() returned undef when not provided correct number of arguments");

$rv = $self->fcopy(undef, 'foo');
ok(! defined $rv, "fcopy() returned undef when first argument was undefined");

$rv = $self->fcopy('foo', undef);
ok(! defined $rv, "fcopy() returned undef when second argument was undefined");

$rv = $self->fcopy('foo', 'foo');
ok(! defined $rv, "fcopy() returned undef when provided 2 identical arguments");

if ($self->{Link}) {
    my $self = File::Copy::Recursive::Reduced->new({debug => 1});
    ok($self->{debug}, "new(): debugging on");
    my $tdir = tempdir( CLEANUP => 1 );
    my ($old, $new) = create_tfile_and_new_path($tdir);
    my $rv = link($old, $new) or croak "Unable to link";
    ok($rv, "Able to hard link $old and $new");
    my $stderr = capture_stderr { $rv = $self->fcopy($old, $new); };
    ok(! defined $rv,
        "fcopy() returned undef when provided arguments with identical dev and ino");
    SKIP: {
        skip 'identical-dev-ino check not applicable on Windows', 1
            if ($^O eq 'MSWin32') ;
        like($stderr, qr/\Q$old and $new are identical\E/,
            "fcopy(): got expected warning when provided arguments with identical dev and ino");
    }
}

# good args #

{
    my $self = File::Copy::Recursive::Reduced->new({debug => 1});
    my $tdir = tempdir( CLEANUP => 1 );
    my ($old, $new) = create_tfile_and_new_path($tdir);
    my ($rv, $stderr);
    my $old_mode = get_mode($old);
    $stderr = capture_stderr { $rv = $self->fcopy($old, $new); };
    ok($rv, "fcopy() returned true value");
    like($stderr, qr/^from:.*?to:/, "fcopy(): got plausible debugging output");
    ok(-f $new, "$new created");
    my $new_mode = get_mode($new);
    cmp_ok($new_mode, 'eq', $old_mode, "fcopy(): mode preserved: $old_mode to $new_mode");
}

SKIP: {
    skip 'mode preservation apparently not significant on Windows', 5
        if ($^O eq 'MSWin32') ;

    my $self = File::Copy::Recursive::Reduced->new({ KeepMode => 0 });
    ok(! $self->{KeepMode}, "new(): KeepMode is turned off");
    my $tdir = tempdir( CLEANUP => 1 );
    my ($old, $new) = create_tfile_and_new_path($tdir);
    my $cnt = chmod 0700, $old;
    ok($cnt, "chmod on $old");
    my $old_mode = get_mode($old);
    my $rv = $self->fcopy($old, $new);
    ok($rv, "fcopy() returned true value");
    ok(-f $new, "$new created");
    my $new_mode = get_mode($new);
    cmp_ok($new_mode, 'ne', $old_mode,
        "fcopy(): With KeepMode turned off, mode not preserved from $old_mode to $new_mode");
}

{
    my $self = File::Copy::Recursive::Reduced->new({});
    ok($self->{KeepMode}, "new(): KeepMode is on");
    my $tdir = tempdir( CLEANUP => 1 );
    my ($old, $new) = create_tfile_and_new_path($tdir);
    my $cnt = chmod 0700, $old;
    ok($cnt, "chmod on $old");
    my $old_mode = get_mode($old);
    my $rv = $self->fcopy($old, $new);
    ok($rv, "fcopy() returned true value");
    ok(-f $new, "$new created");
    my $new_mode = get_mode($new);
    cmp_ok($new_mode, 'eq', $old_mode,
        "fcopy(): With KeepMode on, mode preserved from $old_mode to $new_mode");
}

{
    my $self = File::Copy::Recursive::Reduced->new();
    my $tdir = tempdir( CLEANUP => 1 );
    my ($old, $new) = create_tfile_and_new_path($tdir);
    my @rvs = $self->fcopy($old, $new);
    is_deeply( [ @rvs ], [ 1, 0, 0 ],
        "fcopy(): Got expected return values in list context");
    ok(-f $new, "$new created");
}

{
    my $self = File::Copy::Recursive::Reduced->new();
    my $tdir = tempdir( CLEANUP => 1 );
    my $old = create_tfile($tdir);
    my $newpath = File::Spec->catdir($tdir, 'newpath');
    my $new = File::Spec->catfile($newpath, 'new');
    my $buffer = (1024 * 1024 * 2) + 1;
    my $rv;
    eval { $rv = $self->fcopy($old, $new, $buffer); };
    ok($rv, "fcopy(): Providing buffer as third argument at least does not die");
    ok(-f $new, "$new created");
}

{
    my $self = File::Copy::Recursive::Reduced->new({ debug => 1 });
    my $tdir = tempdir( CLEANUP => 1 );
    my $old = create_tfile($tdir);
    my $newpath = File::Spec->catdir($tdir, 'newpath');
    my $new = File::Spec->catfile($newpath, 'new');
    my $buffer = (1024 * 1024 * 2) + 1;
    my ($rv, $stderr);
    $stderr = capture_stderr { $rv = $self->fcopy($old, $new, $buffer); };
    ok($rv, "fcopy(): Providing buffer as third argument at least does not die");
    like($stderr, qr/^from:.*?to:.*?buf:/, "fcopy(): got plausible debugging output");
    ok(-f $new, "$new created");
}

SKIP: {
    skip 'symlinks not available on this platform', 4
        unless $self->{CopyLink};

    my ($self, $tdir, $old, $new, $symlink, $rv);
    $self = File::Copy::Recursive::Reduced->new();
    $tdir = tempdir( CLEANUP => 1 );
    $old = create_tfile($tdir);
    $symlink = File::Spec->catfile($tdir, 'sym');
    $rv = symlink($old, $symlink)
        or croak "Unable to symlink $symlink to target $old for testing";
    ok(-l $symlink, "fcopy(): $symlink is indeed a symlink");
    $new = File::Spec->catfile($tdir, 'new');
    $rv = $self->fcopy($symlink, $new);
    ok($rv, "fcopy() returned true value when copying from symlink");
    ok(-f $new, "fcopy(): $new is a file");
    ok(-l $new, "fcopy(): but $new is also another symlink");

    my ($xold, $xnew, $xsymlink, $stderr);
    $xold = create_tfile($tdir);
    $xsymlink = File::Spec->catfile($tdir, 'xsym');
    $rv = symlink($xold, $xsymlink)
        or croak "Unable to symlink $xsymlink to target $xold for testing";
    ok(-l $xsymlink, "fcopy(): $xsymlink is indeed a symlink");
    $xnew = File::Spec->catfile($tdir, 'xnew');
    unlink $xold or croak "Unable to unlink $xold during testing";
    $stderr = capture_stderr { $rv = $self->fcopy($xsymlink, $xnew); };
    ok($rv, "fcopy() returned true value when copying from symlink");
    like($stderr, qr/Copying a symlink \($xsymlink\) whose target does not exist/,
        "fcopy(): Got expected warning when copying from symlink whose target does not exist");

}

{
    note("Tests from FCR t/01.legacy.t");
    my ($self, $tdir, $old, $new, $symlink, $rv);
    $self = File::Copy::Recursive::Reduced->new();
    my $tmpd = get_fresh_tmp_dir($self);
    ok(-d $tmpd, "$tmpd exists");

    # that fcopy copies files and symlinks is covered by the dircopy tests, specifically _is_deeply_path()
    $rv = $self->fcopy( "$tmpd/orig/data", "$tmpd/fcopy" );
    is(
        path("$tmpd/orig/data")->slurp,
        path("$tmpd/fcopy")->slurp,
        "fcopy() defaults as expected when target does not exist"
    );

    path("$tmpd/fcopyexisty")->spew("oh hai");
    my @fcopy_rv = $self->fcopy( "$tmpd/orig/data", "$tmpd/fcopyexisty");
    is(
        path("$tmpd/orig/data")->slurp,
        path("$tmpd/fcopyexisty")->slurp,
        "fcopy() defaults as expected when target does exist"
    );

    $rv = $self->fcopy( "$tmpd/orig", "$tmpd/fcopy" );
    ok(!$rv, "fcopy() returns false if source is a directory");
}

{
    note("Tests using FCR's fcopy() from CPAN::Reporter's test suite");
    # t/66_have_tested.t
    # t/72_rename_history.t
    my $config_dir = File::Spec->catdir( MockHomeDir::home_dir, ".cpanreporter" );
    my $config_file = File::Spec->catfile( $config_dir, "config.ini" );
    my $history_file = File::Spec->catfile( $config_dir, "reports-sent.db" );
    my $sample_history_file = File::Spec->catfile(qw/t history reports-sent-longer.db/); 
    mkpath( $config_dir );
    ok( -d $config_dir, "temporary config dir created" );
    
    # CPAN::Reporter:If old history exists, convert it
    # I'm not really sure what the point of this test is.
    SKIP: {
        skip "$sample_history_file does not exist", 1
            unless -e $sample_history_file;
        my $self = File::Copy::Recursive::Reduced->new({ debug => 1 });
        $self->fcopy($sample_history_file, $history_file);
        ok( -f $history_file, "copied sample old history file to config directory");
    }
}


########## SUBROUTINES ##########

sub create_tfile {
    my $tdir = shift;
    my $old = File::Spec->catfile($tdir, 'old');
    open my $OUT, '>', $old or croak "Unable to open for writing";
    binmode $OUT;
    print $OUT "\n";
    close $OUT or croak "Unable to close after writing";
    return $old;
}

sub create_tfile_and_new_path {
    my $tdir = shift;
    my $old = create_tfile($tdir);
    my $new = File::Spec->catfile($tdir, 'new');
    return ($old, $new);
}

sub get_mode {
    my $file = shift;
    return sprintf("%04o" => ((stat($file))[2] & 07777));
}

sub get_fresh_tmp_dir {
    # Adapted from FCR t/01.legacy.t
    my $self = shift;
    my $tmpd = tempdir( CLEANUP => 1 );
    for my $dir ( _get_dirs($tmpd) ) {
        my @created = mkpath($dir, { mode => 0711 });
        croak "Unable to create directory $dir for testing" unless @created;

        path("$dir/empty")->spew("");
        path("$dir/data")->spew("oh hai\n$dir");
        path("$dir/data_tnl")->spew("oh hai\n$dir\n");
        if ($self->{CopyLink}) {
            symlink( "data",    "$dir/symlink" );
            symlink( "noexist", "$dir/symlink-broken" );
            symlink( "..",      "$dir/symlink-loopy" );
        }
    }
    return $tmpd;
}

sub _get_dirs {
    # Adapted from FCR t/01.legacy.t
    my $tempd = shift;
    my @dirs = (
        [ qw| orig | ],
        [ qw| orig foo | ],
        [ qw| orig foo bar | ],
        [ qw| orig foo baz | ],
        [ qw| orig foo bar bletch | ],
    );
    my @catdirs = ();
    for my $set (@dirs) {
        push @catdirs, File::Spec->catdir($tempd, @{$set});
    }
    return @catdirs;
}

