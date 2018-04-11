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

{
    local $@;
    my $bad_arg = 'foo';
    eval { $self = File::Copy::Recursive::Reduced->new( { $bad_arg => 'bar' } ); };
    like($@, qr/'$bad_arg' is not a valid argument to new\(\)/,
        "new(): got expected error message for invalid argument");
}

# good args #

$self = File::Copy::Recursive::Reduced->new();
ok(defined $self, "new() returned defined value when no arguments were provided");
isa_ok($self, 'File::Copy::Recursive::Reduced');

$self = File::Copy::Recursive::Reduced->new({});
ok(defined $self, "new() returned defined value when empty hashref was provided");
isa_ok($self, 'File::Copy::Recursive::Reduced');
ok($self->{PFSCheck}, "PFSCheck turned on by default");

$self = File::Copy::Recursive::Reduced->new({ PFSCheck => 0 });
ok(defined $self, "new() returned defined value when PFSCheck was turned off");
isa_ok($self, 'File::Copy::Recursive::Reduced');
ok(! $self->{PFSCheck}, "PFSCheck can be turned off");

$self = File::Copy::Recursive::Reduced->new({ KeepMode => 0 });
ok(defined $self, "new() returned defined value when KeepMode was turned off");
isa_ok($self, 'File::Copy::Recursive::Reduced');
ok(! $self->{KeepMode}, "KeepMode can be turned off");

$self = File::Copy::Recursive::Reduced->new({ debug => 1 });
ok(defined $self, "new() returned defined value when debug was turned off");
isa_ok($self, 'File::Copy::Recursive::Reduced');
ok($self->{debug}, "debug can be turned on");

$self->{CopyLink} ? pass("System supports symlinks")   : pass("System does not support symlinks");
$self->{Link}     ? pass("System supports hard links") : pass("System does not support hard links");
is($self->{DirPerms}, '0777', "Permissions for directories to be created are set by default to 0777");
