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
    my ($old, $new) = create_tfile($tdir);
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

{
    my $self = File::Copy::Recursive::Reduced->new({debug => 1});
    my $tdir = tempdir( CLEANUP => 1 );
    my ($old, $new) = create_tfile($tdir);
    my ($rv, $stderr);
    $stderr = capture_stderr { $rv = $self->fcopy($old, $new); };
    ok($rv, "fcopy() returned true value");
    like($stderr, qr/^from:.*?to:/, "fcopy(): got plausible debugging output");
}

{
    my $tdir = tempdir( CLEANUP => 1 );
    my ($old, $new) = create_tfile($tdir);
    my $rv = $self->fcopy($old, $new);
    ok($rv, "fcopy() returned true value");
}

{
    my $tdir = tempdir( CLEANUP => 1 );
    my ($old, $new) = create_tfile($tdir);
    my @rvs = $self->fcopy($old, $new);
    is_deeply( [ @rvs ], [ 1, 0, 0 ],
        "fcopy(): Got expected return values in list context");
}

{
    my $tdir = tempdir( CLEANUP => 1 );
    my $old = File::Spec->catfile($tdir, 'old');
    open my $OUT, '>', $old or croak "Unable to open for writing";
    print $OUT "\n";
    close $OUT or croak "Unable to close after writing";
    my $newpath = File::Spec->catdir($tdir, 'newpath');
    my $new = File::Spec->catfile($newpath, 'new');
    my $rv = $self->fcopy($old, $new);
    ok($rv, "fcopy() returned true value");
}

sub create_tfile {
    my $tdir = shift;
    my $old = File::Spec->catfile($tdir, 'old');
    my $new = File::Spec->catfile($tdir, 'new');
    open my $OUT, '>', $old or croak "Unable to open for writing";
    print $OUT "\n";
    close $OUT or croak "Unable to close after writing";
    return ($old, $new);
}
