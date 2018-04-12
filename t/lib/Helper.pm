package Helper;
use strict;
BEGIN{ if (not $] < 5.006) { require warnings; warnings->import } }

use vars qw/@EXPORT_OK @ISA/;
use Exporter ();
@ISA = 'Exporter';
@EXPORT_OK = ( qw|
    create_tfile
    create_tfile_and_new_path
    get_mode
    create_tsubdir
    get_fresh_tmp_dir
| );
use Carp;
use File::Spec;
use File::Temp ( qw| tempdir | );
use File::Path ( qw| mkpath | );
use Path::Tiny;

sub create_tfile {
    my $tdir = shift;
    my $filename = shift || 'old';
    my $old = File::Spec->catfile($tdir, $filename);
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

sub create_tsubdir {
    my $tdir = shift;
    my $old = File::Spec->catdir($tdir, 'old_dir');
    my $rv = mkdir($old);
    croak "Unable to create temporary subdirectory for testing"
        unless $rv;
    return $old;
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

1;
