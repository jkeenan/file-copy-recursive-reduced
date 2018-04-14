package File::Copy::Recursive::Reduced;
use strict;

BEGIN {
    # Keep older versions of Perl from trying to use lexical warnings
    $INC{'warnings.pm'} = "fake warnings entry for < 5.6 perl ($])" if $] < 5.006;
}
use warnings;

use File::Copy;
use File::Find;
use File::Path qw( mkpath );
use File::Spec;

our $VERSION = '0.001';

=head1 NAME

File::Copy::Recursive::Reduced - Recursive copying of files and directories within Perl 5 toolchain

=head1 SYNOPSIS

    use File::Copy::Recursive::Reduced qw(fcopy dircopy);

    fcopy($orig,$new) or die $!;

    dircopy($orig,$new) or die $!;

=head1 DESCRIPTION

This library is intended as a not-quite-drop-in replacement for certain
functionality provided by L<CPAN distribution
File-Copy-Recursive|http://search.cpan.org/dist/File-Copy-Recursive/>.  The
library provides methods similar enough to that distribution's C<fcopy()> and
C<dircopy()> functions to be usable in those CPAN distributions often
described as being part of the Perl toolchain.

=head2 Rationale

F<File::Copy::Recursive> (hereinafter referred to as B<FCR>) is heavily used
in other CPAN libraries.  Out of over 30,000 other CPAN distributions studied
in early 2018, it ranks in one calculation as the 129th highest distribution
in terms of its total direct and indirect reverse dependencies.  Hence, it has
to work correctly and be installable on all operating systems where Perl is
well supported.

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
intended to provide little more than a minimal subset of FCR's functionality
-- just enough to get the Perl toolchain working on the platforms where FCR is
currently failing.  Functions will be added to FCR2 only insofar as
investigation shows that they can replace usage of FCR functions in toolchain
and other heavily used modules.  No attempt will be made to reproduce all the
functionality currently provided or claimed to be provided by FCR.

=head1 SUBROUTINES

The current version of FCR2 provides two exportable and publicly supported
subroutines partially equivalent to the similarly named subroutines exported
by FCR.

=head2 C<fcopy()>

=over 4

=item * Purpose

A stripped-down replacement for C<File::Copy::Recursive::fcopy()>.

Copies a file to a new location, recursively creating directories as needed.
Does not copy directories.  Unlike C<File::Copy::copy()>, C<fcopy()> attempts
to preserve the mode of the original file.

=item * Arguments

    fcopy($orig, $new) or die $!;

Two required arguments: the file to be copied and the location where it is to
be copied.

=item * Return Value

Returns C<1> upon success; C<0> upon failure.  Returns an undefined value if,
for example, function cannot validate arguments.

=item * Comment

Since C<fcopy()> internally uses C<File::Copy::copy()> to perform the copying,
the arguments are subject to the same qualifications as that function's
arguments.  Call F<perldoc File::Copy> for discussion of those arguments.

=item * Restrictions

=over 4

=item *

Does not currently handle copying of symlinks, though it may do so in a future
version.

=back

=back

=cut

sub fcopy {
    return if @_ != 2;
    my ($from, $to) = @_;
    return unless _samecheck($from, $to);
    my ( $volm, $path ) = File::Spec->splitpath($to);
    if ( $path && !-d $path ) {
        pathmk(File::Spec->catpath($volm, $path, ''));
    }
    if (-l $from) { return; }
    elsif (-d $from && -f $to) { return; }
    else {
        copy($from, $to) or return;

        my @base_file = File::Spec->splitpath( $from );
        my $mode_trg = -d $to ? File::Spec->catfile( $to, $base_file[$#base_file] ) : $to;

        chmod scalar((stat($from))[2]), $mode_trg;
    }
    return 1;
}

sub pathmk {
    my ( $vol, $dir, $file ) = File::Spec->splitpath( shift() );

    if ( defined($dir) ) {
        my (@dirs) = File::Spec->splitdir($dir);

        for ( my $i = 0; $i < scalar(@dirs); $i++ ) {
            my $newdir = File::Spec->catdir( @dirs[ 0 .. $i ] );
            my $newpth = File::Spec->catpath( $vol, $newdir, "" );

            mkdir( $newpth ) or return if !-d $newpth;
            mkdir( $newpth ) if !-d $newpth;
        }
    }

    if ( defined($file) ) {
        my $newpth = File::Spec->catpath( $vol, $dir, $file );

        mkdir( $newpth ) or return if !-d $newpth;
        mkdir( $newpth ) if !-d $newpth;
    }

    return 1;
}


=head2 C<dircopy()>

=over 4

=item * Purpose

A stripped-down replacement for C<File::Copy::Recursive::dircopy()>.

Given the path to the directory specified by the first argument,
copies all of the files and directories beneath it to the directory specified
by the second argument.

=item * Arguments

    my $count = dircopy($orig, $new);
    warn "dircopy() returned undefined value" unless defined $count;

=item * Return Value

Upon completion, returns the count of directories and files created -- which
might be C<0>.

Should the function not complete (but not C<die>), an undefined value will be
returned.  That generally indicates problems with argument validation and is
done for consistency with C<File::Copy::Recursive::dircopy>.

=item * Restrictions

None of C<File::Copy::Recursive::dircopy>'s bells and whistles.
No provision for special handling of symlinks.  No preservation of file or
directory modes.  No restriction on maximum depth.  No nothing; this is
fine-tuned to the needs of the F<CPAN::Reporter> test suite.

=back

=cut

sub dircopy {
    my ($orig, $new) = @_;
    return unless _samecheck($orig, $new);
    my $count = 0;
    unless (-d $new) {
        mkpath($new) or die "Unable to mkpath $new: $!";
        $count++;
    }

    my %files_seen = ();
    my %dirs_seen = ();
    my @dirs_needed = ();
    my $wanted = sub {

        if (-d _) {
            my $d = $File::Find::dir;
            my $e = $d;
            $e =~ s{^\Q$orig\E/(.*)}{$1};
            unless ($dirs_seen{$d}) {
                unless ($e eq $orig) {
                    my $copy_dir = File::Spec->catdir($new, $e);
                    unless ($dirs_seen{$e}) {
                        $dirs_seen{$e} = $copy_dir;
                        push @dirs_needed, $copy_dir;
                    }
                }
            }
        }
        if (-f $_) {
            my $f = File::Spec->catfile($File::Find::name);
            my $g = $f;
            $g =~ s{^\Q$orig\E/(.*)}{$1};
            my $copy_file = File::Spec->catfile($new, $g);
            $files_seen{$f} = $copy_file
                unless $files_seen{$g};
        }
    };

    find($wanted, ($orig));

    for my $d (@dirs_needed) {
        mkpath $d or die "Unable to mkpath $d: $!";
        $count++;
    }
    for my $f (sort keys %files_seen) {
        copy($f => $files_seen{$f})
            or die "Unable to copy $f to $files_seen{$f}: $!";
        $count++;
    }

    return $count;
}

sub _samecheck {
	# Adapted from File::Copy::Recursive
    my ($from, $to) = @_;
    return if !defined $from || !defined $to;
    return if $from eq $to;

    if ($^O ne 'MSWin32') {
        # perldoc perlport: "(Win32) "dev" and "ino" are not meaningful."
        # Will probably have to add restrictions for VMS and other OSes.
        my $one = join( '-', ( stat $from )[ 0, 1 ] ) || '';
        my $two = join( '-', ( stat $to   )[ 0, 1 ] ) || '';
        if ( $one and $one eq $two ) {
            warn "$from and $to are identical";
            return;
        }
    }
    return 1;
}

=head2 File::Copy::Recursive Subroutines Not Supported in File::Copy::Recursive::Reduced

As of the current version, FCR2 has no publicly documented, exportable subroutines equivalent
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

Consideration is being given to supporting C<rcopy()>.

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

