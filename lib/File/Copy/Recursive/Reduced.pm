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

#$MaxDepth = 0;
#$KeepMode = 1;
#$CPRFComp = 0;
#$CopyLink = eval { local $SIG{'__DIE__'}; symlink '', ''; 1 } || 0;
#$PFSCheck = 1;
#$RemvBase = 0;
#$NoFtlPth = 0;
#$ForcePth = 0;
#$CopyLoop = 0;
#$RMTrgFil = 0;
#$RMTrgDir = 0;
#$CondCopy = {};
#$BdTrgWrn = 0;
#$SkipFlop = 0;
#$DirPerms = 0777;

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

The current version of FCR2 provides a constructor and three public methods
partially equivalent to the similarly named functions exported by FCR.

=head2 C<new()>

=over 4

=item * Purpose

=item * Arguments

    $self = File::Copy::Recursive::Reduced->new({});

=item * Return Value

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
    my %valid_args = map {$_ => 1} qw( PFSCheck KeepMode debug );
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

=item 3

Buffer size:  the number of bytes from the first file which will be held in memory at any given time before being written to the second file.

=back

Since C<fcopy()> internally uses C<File::Copy::copy()> to perform the copying,
the arguments are subject to the same qualifications as that function.  Call
F<perldoc File::Copy> for discussion of those arguments.

=item * Return Value

Scalar context: returns C<1> upon success; C<0> upon failure.

List context: returns a 3-element list: C<(1,0,0)> upon success; C<0,0,0)> upon failure.  TODO: Verify!

=item * Comments

=over 4

=item *

Unlike FCR's C<fcopy()>, this method provides no functionality to remove the
original file before copying.

=item * TODO

=over 4

=item * Decide status of symlinks in first argument.

=item * Decide status of C<$File::Copy::Recursive::BdTrgWrn>.

=item * Decide status of C<$File::Copy::Recursive::KeepMode>.

=back

=cut

sub fcopy {
    my ($self, $from, $to, $buf) = @_;
    return if @_ < 3 or @_ > 4;
    return unless $self->_samecheck($from, $to);
    my ( $volm, $path ) = File::Spec->splitpath($to);
    if ( $path && !-d $path ) {
        $self->pathmk(File::Spec->catpath($volm, $path, ''));
    }
#    if ( -l $_[0] && $CopyLink ) {
#        my $target = readlink( shift() );
#        ($target) = $target =~ m/(.*)/;    # mass-untaint is OK since we have to allow what the file system does
#        carp "Copying a symlink ($_[0]) whose target does not exist"
#          if !-e $target && $BdTrgWrn;
#        my $new = shift();
#        unlink $new if -l $new;
#        symlink( $target, $new ) or return;
#    }
#    else {
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
#    }
    # TODO: Is this advice superseded?
    # use 0's in case they do math on them and in case rcopy() is called 
    # in list context = no uninit val warnings
    return wantarray ? ( 1, 0, 0 ) : 1;
}

    
=head2 C<dircopy()>

=over 4

=item * Purpose

=item * Arguments

    $self->dircopy($orig,$new[,$buf]) or die $!;

=item * Return Value

=item * Comment

=back

=cut

sub dircopy {}

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

#sub dircopy {
#    if ( $RMTrgDir && -d $_[1] ) {
#        if ( $RMTrgDir == 1 ) {
#            pathrmdir( $_[1] ) or carp "\$RMTrgDir failed: $!";
#        }
#        else {
#            pathrmdir( $_[1] ) or return;
#        }
#    }
#    my $globstar = 0;
#    my $_zero    = $_[0];
#    my $_one     = $_[1];
#    if ( substr( $_zero, ( 1 * -1 ), 1 ) eq '*' ) {
#        $globstar = 1;
#        $_zero = substr( $_zero, 0, ( length($_zero) - 1 ) );
#    }
#
#    $samecheck->( $_zero, $_[1] ) or return;
#    if ( !-d $_zero || ( -e $_[1] && !-d $_[1] ) ) {
#        $! = 20;
#        return;
#    }
#
#    if ( !-d $_[1] ) {
#        pathmk( $_[1], $NoFtlPth ) or return;
#    }
#    else {
#        if ( $CPRFComp && !$globstar ) {
#            my @parts = File::Spec->splitdir($_zero);
#            while ( $parts[$#parts] eq '' ) { pop @parts; }
#            $_one = File::Spec->catdir( $_[1], $parts[$#parts] );
#        }
#    }
#    my $baseend = $_one;
#    my $level   = 0;
#    my $filen   = 0;
#    my $dirn    = 0;
#
#    my $recurs;    #must be my()ed before sub {} since it calls itself
#    $recurs = sub {
#        my ( $str, $end, $buf ) = @_;
#        $filen++ if $end eq $baseend;
#        $dirn++  if $end eq $baseend;
#
#        $DirPerms = oct($DirPerms) if substr( $DirPerms, 0, 1 ) eq '0';
#        mkdir( $end, $DirPerms ) or return if !-d $end;
#        if ( $MaxDepth && $MaxDepth =~ m/^\d+$/ && $level >= $MaxDepth ) {
#            chmod scalar( ( stat($str) )[2] ), $end if $KeepMode;
#            return ( $filen, $dirn, $level ) if wantarray;
#            return $filen;
#        }
#
#        $level++;
#
#        my @files;
#        if ( $] < 5.006 ) {
#            opendir( STR_DH, $str ) or return;
#            @files = grep( $_ ne '.' && $_ ne '..', readdir(STR_DH) );
#            closedir STR_DH;
#        }
#        else {
#            opendir( my $str_dh, $str ) or return;
#            @files = grep( $_ ne '.' && $_ ne '..', readdir($str_dh) );
#            closedir $str_dh;
#        }
#
#        for my $file (@files) {
#            my ($file_ut) = $file =~ m{ (.*) }xms;
#            my $org = File::Spec->catfile( $str, $file_ut );
#            my $new = File::Spec->catfile( $end, $file_ut );
#            if ( -l $org && $CopyLink ) {
#                my $target = readlink($org);
#                ($target) = $target =~ m/(.*)/;    # mass-untaint is OK since we have to allow what the file system does
#                carp "Copying a symlink ($org) whose target does not exist"
#                  if !-e $target && $BdTrgWrn;
#                unlink $new if -l $new;
#                symlink( $target, $new ) or return;
#            }
#            elsif ( -d $org ) {
#                my $rc;
#                if ( !-w $org && $KeepMode ) {
#                    local $KeepMode = 0;
#                    carp "Copying readonly directory ($org); mode of its contents may not be preserved.";
#                    $rc = $recurs->( $org, $new, $buf ) if defined $buf;
#                    $rc = $recurs->( $org, $new ) if !defined $buf;
#                    chmod scalar( ( stat($org) )[2] ), $new;
#                }
#                else {
#                    $rc = $recurs->( $org, $new, $buf ) if defined $buf;
#                    $rc = $recurs->( $org, $new ) if !defined $buf;
#                }
#                if ( !$rc ) {
#                    if ($SkipFlop) {
#                        next;
#                    }
#                    else {
#                        return;
#                    }
#                }
#                $filen++;
#                $dirn++;
#            }
#            else {
#                if ( $ok_todo_asper_condcopy->($org) ) {
#                    if ($SkipFlop) {
#                        fcopy( $org, $new, $buf ) or next if defined $buf;
#                        fcopy( $org, $new ) or next if !defined $buf;
#                    }
#                    else {
#                        fcopy( $org, $new, $buf ) or return if defined $buf;
#                        fcopy( $org, $new ) or return if !defined $buf;
#                    }
#                    chmod scalar( ( stat($org) )[2] ), $new if $KeepMode;
#                    $filen++;
#                }
#            }
#        }
#        $level--;
#        chmod scalar( ( stat($str) )[2] ), $end if $KeepMode;
#        1;
#
#    };
#
#    $recurs->( $_zero, $_one, $_[2] ) or return;
#    return wantarray ? ( $filen, $dirn, $level ) : $filen;
#}
#
#sub pathmk {
#    my ( $vol, $dir, $file ) = File::Spec->splitpath( shift() );
#    my $nofatal = shift;
#
#    $DirPerms = oct($DirPerms) if substr( $DirPerms, 0, 1 ) eq '0';
#
#    if ( defined($dir) ) {
#        my (@dirs) = File::Spec->splitdir($dir);
#
#        for ( my $i = 0; $i < scalar(@dirs); $i++ ) {
#            my $newdir = File::Spec->catdir( @dirs[ 0 .. $i ] );
#            my $newpth = File::Spec->catpath( $vol, $newdir, "" );
#
#            mkdir( $newpth, $DirPerms ) or return if !-d $newpth && !$nofatal;
#            mkdir( $newpth, $DirPerms ) if !-d $newpth && $nofatal;
#        }
#    }
#
#    if ( defined($file) ) {
#        my $newpth = File::Spec->catpath( $vol, $dir, $file );
#
#        mkdir( $newpth, $DirPerms ) or return if !-d $newpth && !$nofatal;
#        mkdir( $newpth, $DirPerms ) if !-d $newpth && $nofatal;
#    }
#
#    1;
#}
#
#sub pathrm {
#    my ( $path, $force, $nofail ) = @_;
#
#    my ( $orig_dev, $orig_ino ) = ( lstat $path )[ 0, 1 ];
#    return 2 if !-d _ || !$orig_dev || !$orig_ino;
#
#    my @pth = File::Spec->splitdir($path);
#
#    my %fs_check;
#    my $aggregate_path;
#    for my $part (@pth) {
#        $aggregate_path = defined $aggregate_path ? File::Spec->catdir( $aggregate_path, $part ) : $part;
#        $fs_check{$aggregate_path} = [ ( lstat $aggregate_path )[ 0, 1 ] ];
#    }
#
#    while (@pth) {
#        my $cur = File::Spec->catdir(@pth);
#        last if !$cur;    # necessary ???
#
#        if ($force) {
#            _bail_if_changed( $cur, $fs_check{$cur}->[0], $fs_check{$cur}->[1] );
#            if ( !pathempty($cur) ) {
#                return unless $nofail;
#            }
#        }
#        _bail_if_changed( $cur, $fs_check{$cur}->[0], $fs_check{$cur}->[1] );
#        if ($nofail) {
#            rmdir $cur;
#        }
#        else {
#            rmdir $cur or return;
#        }
#        pop @pth;
#    }
#
#    return 1;
#}
#
#sub pathrmdir {
#    my $dir = shift;
#    if ( -e $dir ) {
#        return if !-d $dir;
#    }
#    else {
#        return 2;
#    }
#
#    my ( $orig_dev, $orig_ino ) = ( lstat $dir )[ 0, 1 ];
#    return 2 if !$orig_dev || !$orig_ino;
#
#    pathempty($dir) or return;
#    _bail_if_changed( $dir, $orig_dev, $orig_ino );
#    rmdir $dir or return;
#
#    return 1;
#}
#
#sub _bail_if_changed {
#    my ( $path, $orig_dev, $orig_ino ) = @_;
#
#    my ( $cur_dev, $cur_ino ) = ( lstat $path )[ 0, 1 ];
#
#    if ( !defined $cur_dev || !defined $cur_ino ) {
#        $cur_dev ||= "undef(path went away?)";
#        $cur_ino ||= "undef(path went away?)";
#    }
#    else {
#        $path = Cwd::abs_path($path);
#    }
#
#    if ( $orig_dev ne $cur_dev || $orig_ino ne $cur_ino ) {
#        local $Carp::CarpLevel += 1;
#        Carp::croak("directory $path changed: expected dev=$orig_dev ino=$orig_ino, actual dev=$cur_dev ino=$cur_ino, aborting");
#    }
#}

1;

__END__

