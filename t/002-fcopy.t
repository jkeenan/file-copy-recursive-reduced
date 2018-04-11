# -*- perl -*-
# t/002-fcopy.t - tests of fcopy() method
use strict;
use warnings;

use Test::More qw(no_plan); # tests =>  2;
use Carp;
use Capture::Tiny qw(capture_stdout capture_stderr);
use File::Spec;
use File::Temp qw(tempfile tempdir);

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

{
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
