package CygwinHelper;
use strict;
use warnings;

our (@EXPORT_OK, @ISA);
use Exporter ();
@ISA = 'Exporter';
@EXPORT_OK = qw( env_prefix );

sub env_prefix {
    my $mode = shift;
    my $OS = uc $^O;
    my $prefix = "$OS=";
    $prefix .= "winsymlinks:$mode" if defined $mode;
    return $prefix;
}

1;