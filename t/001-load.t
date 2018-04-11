# -*- perl -*-
# t/001-load.t - check module loading and create testing directory
use strict;
use warnings;

use Test::More qw(no_plan); # tests =>  2;

BEGIN { use_ok( 'File::Copy::Recursive::Reduced' ); }

my ($self, );
# bad args #
{
    local $@;
    eval { $self = File::Copy::Recursive::Reduced->new( [] ); };
    like($@, qr/Argument to constructor must be hashref/,
        "new(): got expected error message for non-hashref argument");
}

# good args #

$self = File::Copy::Recursive::Reduced->new();
ok(defined $self, "new() returned defined value when no arguments were provided");
isa_ok($self, 'File::Copy::Recursive::Reduced');

$self = File::Copy::Recursive::Reduced->new({});
ok(defined $self, "new() returned defined value when empty hashref was provided");
isa_ok($self, 'File::Copy::Recursive::Reduced');
