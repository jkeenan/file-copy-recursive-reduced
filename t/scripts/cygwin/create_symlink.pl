use strict;
use warnings;
use feature qw(say);

use File::Temp qw(tempdir);

{
    my $dir = tempdir( CLEANUP => 1 );
    chdir $dir;
    my $fn = 'a';
    # Create an empty file..
    open my $fh, '>', $fn or exit 2;
    close $fh or exit 2;
    if( symlink 'a', 'b') {
        exit 0;
    }
    else {
        exit 1;
    }
}