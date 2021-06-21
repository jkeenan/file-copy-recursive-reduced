use strict;
use warnings;
use feature qw(say);

use File::Temp qw(tempdir);
use File::Copy::Recursive::Reduced qw( fcopy );
use lib qw( t/lib );
use Helper qw(create_tfile run_bash_cmd run_system_cmd);
use CygwinHelper qw(env_prefix);

{
    my $dir = tempdir( CLEANUP => 1 );
    my $fn = 'a';
    create_tfile($dir, $fn);
    # Since we have a valid target, using winsymlinks:native with ln -s should never fail
    #   to create a symlink.
    my $target = File::Spec->catfile( $dir, $fn);
    my $dest = File::Spec->catfile( $dir, 'b');
    my $prefix = env_prefix("native");
    my $cmd = "$prefix ln -s $target $dest";
    {
        my $res = run_bash_cmd($cmd);
        die "ln -s failed: $!" if $res != 0;
    }
    unlink $target or die "Could not delete symlink target: $!";
    my $src_fn = $dest;
    my $dest_fn = File::Spec->catfile($dir, 'c');
    my $res = fcopy($src_fn, $dest_fn);
    exit 2 if !defined $res;
    exit 1 if $res == 1;
    exit 0 if $res == 0;
    exit 3;
}