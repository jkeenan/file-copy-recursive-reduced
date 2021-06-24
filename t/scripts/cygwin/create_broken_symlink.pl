use strict;
use warnings;
use feature qw(say);

use File::Temp qw(tempdir);

{
    my $dir = tempdir( CLEANUP => 1 );
    chdir $dir;
    #say "MSYS = $ENV{MSYS}";
    if( symlink 'a', 'b') {
        exit 0;
    }
    else {
        exit 1;
    }
}
