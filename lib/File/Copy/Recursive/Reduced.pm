package File::Copy::Recursive::Reduced;
use strict;

BEGIN {
    # Keep older versions of Perl from trying to use lexical warnings
    $INC{'warnings.pm'} = "fake warnings entry for < 5.6 perl ($])" if $] < 5.006;
}
use warnings;

use Carp;
use File::Copy;
use File::Spec;
use Cwd ();

our $VERSION = '0.001';

=head1 NAME

File::Copy::Recursive::Reduced - Recursive copying of files and directories within Perl 5 toolchain

=head1 SYNOPSIS

    use File::Copy::Recursive::Reduced;

    my $self = File::Copy::Recursive::Reduced->new({});
    $self->fcopy($orig,$new[,$buf]) or die $!;
    $self->dircopy($orig,$new[,$buf]) or die $!;

=head1 DESCRIPTION

This library is intended as a not-quite-drop-in replacement for certain
functionality provided by L<CPAN distribution
File-Copy-Recursive|http://search.cpan.org/dist/File-Copy-Recursive/>.  The
library provides methods similar enough to that distribution's C<fcopy()> and
C<dircopy()> functions to be usable in those CPAN distributions often
described as being part of the Perl toolchain.

=head2 Rationale

F<File::Copy::Recursive> (hereinafter referred to as B<FCR>) is heavily used
in other CPAN libraries.  Out of over 30,000 other CPAN distributions, it
ranks, by one estimate, as the 129th highest distribution in terms of number
of direct and indirect reverse dependencies.  Hence, it has to work correctly
and be installable on all operating systems where Perl is well supported.

However, as of the time of creation of F<File::Copy::Recursive::Reduced>
(April 2018), FCR is failing to pass its tests against either Perl 5.26 or
Perl 5 blead on important operating systems including Windows, FreeBSD and
NetBSD
(L<http://fast-matrix.cpantesters.org/?dist=File-Copy-Recursive%200.40>).
CPAN installers such as F<cpan> and F<cpanm> will not install it without
resort to C<--force> options and will prevent distributions dependent on FCR
from being installed as well.  Some patches have been provided to the L<FCR
bug tracker|https://rt.cpan.org/Dist/Display.html?Name=File-Copy-Recursive>
for certain problems but FCR's author has not yet applied them.  Even if,
however, those patches are applied, FCR may not install on certain platforms.

F<File::Copy::Recursive::Reduced> (hereinafter referred to as B<FCR2>) is
intended to provide little more than a minimal subset of FCR's functionality,
that is, just enough to get the Perl toolchain working on the platforms where
FCR is currently failing.  Methods will be added to FCR2 only insofar as
investigation shows that they can replace usage of FCR functions in Toolchain
modules.  No attempt will be made to reproduce all the functionality currently
provided or claimed to be provided by FCR.

=head1 METHODS

The current version of FCR2 provides a constructor and two public methods
partially equivalent to the similarly named functions exported by FCR.

=head2 C<new()>

=over 4

=item * Purpose

File::Copy::Recursive::Reduced constructor.

=item * Arguments

    $self = File::Copy::Recursive::Reduced->new({});

If an argument is provided, it must be a hash reference.  Valid keys for that
hashref are:

=over 4

=item * C<PFSCheck>

On by default; provide a Perl-false value to turn off.

=item * C<KeepMode>

On by default; provide a Perl-false value to turn off.

=item * C<MaxDepth>

Off by default; provide a positive integer to set the maximum depth to which a directory structure
is recursed during C<dircopy()>.

=item * C<debug>

Off by default; provide a Perl-true value to turn off.

=back

=item * Return Value

File::Copy::Recursive::Reduced object.

=item * Comment

=back

=cut

sub new {
    my ($class, $args) = @_;
    unless (defined($args)) {
        $args = {};
    }
    croak "Argument to constructor must be hashref"
        unless ref($args) eq 'HASH';

    my $data = {};
    my %valid_args = map {$_ => 1} qw( PFSCheck KeepMode MaxDepth debug );
    croak "MaxDepth, if provided, must be positive integer"
        if (
            exists $args->{MaxDepth} and
            !(
                $args->{MaxDepth} =~ m/^\d+$/ and
                $args->{MaxDepth} > 0
            )
        );
    for my $k (keys %{$args}) {
        croak "'$k' is not a valid argument to new()" unless $valid_args{$k};
        $data->{$k} = $args->{$k};
    }
    $data->{PFSCheck} = 1 unless exists $data->{PFSCheck};
    $data->{KeepMode} = 1 unless exists $data->{KeepMode};
    $data->{CopyLink} = eval { local $SIG{'__DIE__'}; symlink '', ''; 1 } || 0;
    $data->{Link}     = eval { local $SIG{'__DIE__'}; link    '', ''; 1 } || 0;
    $data->{DirPerms} = '0777';

    return bless $data, $class;
}

=head2 C<fcopy()>

=over 4

=item * Purpose

Copy a file to a new location, recursively creating directories as needed.
Does not copy directories.  Unlike C<File::Copy::copy()>, C<fcopy()> attempts
to preserve the mode of the original file.

=item * Arguments

    $self->fcopy($orig,$new[,$buf]) or die $!;

Takes three arguments, the first two required, the third optional.

=over 4

=item 1 The file to be copied.

=item 2 Path where copy is to be created.

=item 3 Buffer size:  the number of bytes from the first file which will be
held in memory at any given time before being written to the second file.

=back

Since C<fcopy()> internally uses C<File::Copy::copy()> to perform the copying,
the arguments are subject to the same qualifications as that function.  Call
F<perldoc File::Copy> for discussion of those arguments.

=item * Return Value

Scalar context: returns C<1> upon success; C<0> upon failure.

List context: returns a 3-element list: C<(1,0,0)> upon success; C<0,0,0)>
upon failure.

=item * Comments

=over 4

=item *

Unlike FCR's C<fcopy()>, this method provides no functionality to remove an
already existing target file before copying.

=item * TODO

=over 4

=item * Decide status of C<$File::Copy::Recursive::BdTrgWrn>.

At present, I'm not implementing it -- at least not for C<fcopy()>.

=back

=back

=back

=cut

sub fcopy {
    return if @_ < 3 or @_ > 4;
    my ($self, $from, $to, $buf) = @_;
    return unless $self->_samecheck($from, $to);
    my ( $volm, $path ) = File::Spec->splitpath($to);
    if ( $path && !-d $path ) {
        $self->pathmk(File::Spec->catpath($volm, $path, ''));
    }
    if ( -l $from && $self->{CopyLink} ) {
        my $target = readlink($from);
        # FCR: mass-untaint is OK since we have to allow what the file system does
        ($target) = $target =~ m/(.*)/;
        carp "Copying a symlink ($from) whose target does not exist"
            if !-e $target;
        # It's not clear how to exercise the TRUE branch in the following
        # statement.
        unlink $to if -l $to;
        symlink( $target, $to ) or return;
    }
    elsif ( -d $from && -f $to ) {
        return;
    }
    else {
        unless ($buf) {
            if ($self->{debug}) { print STDERR "from: $from\tto: $to\n"; }
            copy($from, $to) or return;
        }
        else          {
            if ($self->{debug}) { print STDERR "from: $from\tto: $to\tbuf: $buf\n"; }
            copy($from, $to, $buf) or return;
        }

        my @base_file = File::Spec->splitpath( $from );
        my $mode_trg = -d $to ? File::Spec->catfile( $to, $base_file[$#base_file] ) : $to;

        chmod scalar((stat($from))[2]), $mode_trg if $self->{KeepMode};
    }
    # TODO: Is this advice superseded?
    # use 0's in case they do math on them and in case rcopy() is called 
    # in list context = no uninit val warnings
    return wantarray ? ( 1, 0, 0 ) : 1;
}

    
=head2 C<dircopy()>

=over 4

=item * Purpose

Recursively traverse a directory and recursively copy it to a new directory.

=item * Arguments

Scalar context:

    my $num_of_files_and_dirs = $self->dircopy($orig,$new[,$buf]) or die $!;

List context:

    my ($num_of_files_and_dirs,$num_of_dirs,$depth_traversed) =
        $self->dircopy($orig,$new[,$buf]) or die $!;

=item * Return Value

Scalar context:  Returns the number of files and directories copied.

List context:  Returns a 3-element list:

=over 4

=item 1 Number of files and directories copied;

=item 2 Number of directories (only) copied;

=item 3 Depth level traversed.

=back

=item * Comment

=over 4

=item *

The C<dircopy()> method creates intermediate directories as needed.  By
default it attempts to preserve the modes of all files and directories.  In
addition, by default it copies all the way down into the directory.

Error conditions: TK

=item *

Unlike FCR's C<dircopy()>, this method provides no functionality to remove
already existing directories or files before copying (C<$RMTrgDir>).

=item *

Unlike FCR's C<dircopy()>, this method provides no functionality to continue
on regardless of the failure to copy an individual directory or file (for
instance, because of inadequate permissions) (C<$SkipFlob>).

=back

=back

=cut

sub dircopy {
    return if @_ < 3 or @_ > 4;
    my ($self, $from, $to, $buf) = @_;
    return unless $self->_samecheck($from, $to);

    if ( !-d $from  || ( -e $to && !-d $to ) ) {
        $! = 20;
        return;
    }

    my $baseend = $from;
    my $level   = 0;
    my $filen   = 0;
    my $dirn    = 0;

    # FCR: must be my()ed before sub {} since it calls itself
    my $recurs;
    $recurs = sub {
    ##        my ( $str, $end, $buf ) = @_;
        my ($self, $from, $to, $buf) = @_;
        $filen++ if $to eq $baseend;
        $dirn++  if $to eq $baseend;

        my $DirPerms = oct($self->{DirPerms}) if substr( $self->{DirPerms}, 0, 1 ) eq '0';
        mkdir( $to, $DirPerms ) or return if !-d $to;

        # If we've set a MaxDepth and are now deeper than that, halt
        # processing and return.
        # (Can't test this until the rest of the coderef is fleshed out.)

        if ( $self->{MaxDepth} && $level >= $self->{MaxDepth} ) {
            chmod scalar( ( stat($from) )[2] ), $to if $self->{KeepMode};
            return ( $filen, $dirn, $level ) if wantarray;
            return $filen;
        }

        $level++;

        my @files;
        if ( $] < 5.006 ) {
            opendir( STR_DH, $from ) or return;
            @files = grep( $_ ne '.' && $_ ne '..', readdir(STR_DH) );
            closedir STR_DH;
        }
        else {
            opendir( my $FROM_DH, $from ) or return;
            @files = grep( $_ ne '.' && $_ ne '..', readdir($FROM_DH) );
            closedir $FROM_DH;
        }

        for my $file (@files) {
            my ($file_ut) = $file =~ m{ (.*) }xms;
            my $org = File::Spec->catfile( $from, $file_ut );
            my $new = File::Spec->catfile( $to, $file_ut );
            if ( -l $org && $self->{CopyLink} ) {
                # $org is a symlink and OS can handle symlinks
                my $target = readlink($org);
                # FCR: mass-untaint is OK since we have to allow what the file system does
                ($target) = $target =~ m/(.*)/;
                carp "Copying a symlink ($org) whose target does not exist"
                  if !-e $target;
                unlink $new if -l $new;
                symlink( $target, $new ) or return;
            }
            elsif ( -d $org ) {
                # $org is a directory
                my $rc;
                if ( !-w $org && $self->{KeepMode} ) {

                    # $org is NOT writable by effective uid/gid and we would
                    # normally want to retain modes (which is default);
                    # so we have to forsake retaining modes

                    local $self->{KeepMode} = 0;
                    carp "Copying readonly directory ($org); mode of its contents may not be preserved.";
                    $rc = $recurs->( $self, $org, $new, $buf ) if  defined $buf;
                    $rc = $recurs->( $self, $org, $new )       if !defined $buf;
                    chmod scalar( ( stat($org) )[2] ), $new;
                }
                else {
                    $rc = $recurs->( $self, $org, $new, $buf ) if  defined $buf;
                    $rc = $recurs->( $self, $org, $new )       if !defined $buf;
                }
                return if ( !$rc );
                $filen++;
                $dirn++;
            }
            else {
                # $org is something other than a symlink or a directory
                # In FRC, this block is apparently a TODO item and currently
                # effectively does nothing
            }
        } # END 'for' loop processing files in 'from' directory

        $level--;
        chmod scalar( ( stat($from) )[2] ), $to if $self->{KeepMode};
        1;
    }; # END definition of coderef $recurs

    # Call the recursive subroutine.
    $recurs->($self, $from, $to, $buf) or return;
    return wantarray ? ( $filen, $dirn, $level ) : $filen;
    return;
}

# pathmk() currently provided only because it is called from within fcopy().
# It will be publicly documented only when need for its use in toolchain
# modules has been demonstrated.

sub pathmk {
    my $self = shift;
    my ( $vol, $dir, $file ) = File::Spec->splitpath( shift() );

    my $DirPerms = oct($self->{DirPerms}) if substr( $self->{DirPerms}, 0, 1 ) eq '0';

    if ( defined($dir) ) {
        my (@dirs) = File::Spec->splitdir($dir);

        for ( my $i = 0; $i < scalar(@dirs); $i++ ) {
            my $newdir = File::Spec->catdir( @dirs[ 0 .. $i ] );
            my $newpth = File::Spec->catpath( $vol, $newdir, "" );

            mkdir( $newpth, $DirPerms ) or return if !-d $newpth;
            mkdir( $newpth, $DirPerms ) if !-d $newpth;
        }
    }

    if ( defined($file) ) {
        my $newpth = File::Spec->catpath( $vol, $dir, $file );

        mkdir( $newpth, $DirPerms ) or return if !-d $newpth;
        mkdir( $newpth, $DirPerms ) if !-d $newpth;
    }

    return 1;
}

# _samecheck() is called from within publicly documented functions but, as was
# the case with FCR, it will not itself be publicly documented.
# At this point, _samecheck() does not have the CopyLoop stuff that $samecheck
# has in FCR.

sub _samecheck {
    my ($self, $from, $to) = @_;
    return if !defined $from || !defined $to;
    return if $from eq $to;

    if ($self->{PFSCheck} and not ($^O eq 'MSWin32')) {
        # perldoc perlport: "(Win32) "dev" and "ino" are not meaningful."
        # Will probably have to add restrictions for VMS and other OSes.
        my $one = join( '-', ( stat $from )[ 0, 1 ] ) || '';
        my $two = join( '-', ( stat $to   )[ 0, 1 ] ) || '';
        if ( $one and $one eq $two ) {
            carp "$from and $to are identical";
            return;
        }
    }
    return 1;
}

=head2 File::Copy::Recursive Subroutines Not Supported in File::Copy::Recursive::Reduced

As of the current version, FCR2 has no publicly documented methods equivalent
to the following FCR exportable subroutines:

    rcopy
    rcopy_glob
    fmove
    rmove
    rmove_glob
    dirmove
    pathempty
    pathrm
    pathrmdir

=head1 BUGS AND SUPPORT

Please report any bugs by mail to C<bug-File-Copy-Recursive-Reduced@rt.cpan.org>
or through the web interface at L<http://rt.cpan.org>.

=head1 ACKNOWLEDGEMENTS

TK

=head1 AUTHOR

    James E Keenan
    CPAN ID: JKEENAN
    jkeenan@cpan.org
    http://thenceforward.net/perl

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

Copyright James E Keenan 2018.  All rights reserved.

=head1 SEE ALSO

perl(1). File::Copy::Recursive(3).

=cut

1;

__END__

