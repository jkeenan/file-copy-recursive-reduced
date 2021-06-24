package File::Copy::Recursive::Reduced;
use strict;
use warnings;

use parent qw( Exporter );
our @EXPORT_OK = qw( dircopy fcopy rcopy );
our $VERSION = '0.006';

use Cwd qw(getcwd);
use Config;
use File::Copy;
use File::Find;
use File::Path qw( mkpath );
use File::Spec;

our $Link       = eval { local $SIG{'__DIE__'}; link    '', ''; 1 } || 0;
our $CopyLink   = eval { local $SIG{'__DIE__'}; symlink '', ''; 1 } || 0;
our $DirPerms   = 0777;


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
library provides methods similar enough to that distribution's C<fcopy()>,
C<dircopy()> and C<rcopy()> functions to be usable in those CPAN distributions
often described as being part of the Perl toolchain.

=head2 Rationale

F<File::Copy::Recursive> (hereinafter referred to as B<FCR>) is heavily used
in other CPAN libraries.  Out of over 30,000 other CPAN distributions studied
in early 2018, it ranks by one calculation as the 129th highest distribution
in terms of its total direct and indirect reverse dependencies.  In current
parlance, it sits C<high upstream on the CPAN river.>  Hence, it ought to work
correctly and be installable on all operating systems where Perl is well
supported.

However, as of early April 2018, FCR version 0.40 wass failing to pass its tests against either
Perl 5.26 or Perl 5 blead on important operating systems including Windows,
FreeBSD and NetBSD
(L<http://fast-matrix.cpantesters.org/?dist=File-Copy-Recursive%200.40>).  As
a consequence, CPAN installers such as F<cpan> and F<cpanm> were failing to
install it (unless one resorted to the C<--force> option).  This prevented
distributions dependent (directly or indirectly) on FCR from being installed
as well.

Some patches had been provided to the L<FCR bug
tracker|https://rt.cpan.org/Dist/Display.html?Name=File-Copy-Recursive> for
this problem.  However, as late as April 18 2018 those patches had not yet
been applied.  This posed a critical problem for the ability to assess the
impact of the soon-to-be-released perl-5.28.0 on CPAN distributions (the
so-called "Blead Breaks CPAN" ("BBC") problem) on platforms other than Linux.

F<File::Copy::Recursive::Reduced> (hereinafter referred to as B<FCR2>) is
intended to provide a minimal subset of FCR's functionality -- just enough to
get the Perl toolchain working on the platforms where FCR is currently
failing.  Functions will be added to FCR2 only insofar as investigation shows
that they can replace usage of FCR functions in toolchain and other heavily
used modules.  No attempt will be made to reproduce all the functionality
currently provided or claimed to be provided by FCR.

On April 19 2018, FCR's author, Daniel Muey, released version 0.41 to CPAN.
This version included a patch submitted by Tom Hukins which corrected the
problem addressed by FCR2.  FCR once again built and tested correctly on
FreeBSD.  That meant that its 6000-plus reverse dependencies can once again be
reached by F<cpan> and other installers.  That in turn means that we can
conduct exhaustive BBC investigations on FreeBSD and other platforms.

With that correction in FCR, the original rationale for FCR2 has been
superseded.  I will continue to maintain the code and respond to bug reports,
but am suspending active development.  I now deem FCR2 feature-complete.

=head1 SUBROUTINES

The current version of FCR2 provides three exportable and publicly supported
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

List of two required arguments:

=over 4

=item * Absolute path to the file being copied; and

=item * Absolute path to the location to which the file is being copied.

=back

Four cases should be noted:

=over 4

=item 1 Create copy within same directory but new basename

    fcopy('/path/to/filename', '/path/to/newfile');

The second argument must be the absolute path to the new file.  (Otherwise
the file will be created in the current working directory, which is almost
certainly what you do not want.)

=item 2 Create copy within different, already B<existing> directory, same basename

    fcopy('/path/to/filename', '/path/to/existing/directory');

The second argument can be merely the path to the existing directory; will
create F</path/to/existing/directory/filename>.

=item 3 Create copy within different, not yet existing directory, same basename

    fcopy('/path/to/filename', '/path/not/yet/existing/directory/filename');

The second argument will be interpreted as the complete path to the newly
created file.  The basename must be included even if it is the same as in the
first argument.  Will create F</path/not/yet/existing/directory/filename>.

=item 4 Create copy within different, not yet existing directory, different basename

    fcopy('/path/to/filename', '/path/not/yet/existing/directory/newfile');

The second argument will be interpreted as the complete path to the newly
created file.  Will create F</path/not/yet/existing/directory/newfile>.

=back

=item * Return Value

Returns C<1> upon success; C<0> upon failure.  Returns an undefined value if,
for example, function cannot validate arguments.

=item * Comment

Since C<fcopy()> internally uses C<File::Copy::copy()> to perform the copying,
the arguments are subject to the same qualifications as that function's
arguments.  Call F<perldoc File::Copy> for discussion of those arguments.

=back

=cut

sub fcopy {
    return unless @_ == 2;
    my ($from, $to) = @_;
    #return unless _samecheck($from, $to);
    return unless _basic_samecheck($from, $to);

    # TODO:  Explore whether we should check (-e $from) here.
    # If we don't have a starting point, it shouldn't make any sense to go
    # farther.

    return unless _dev_ino_check($from, $to);

    return _fcopy($from, $to);
}

sub _fcopy {
    my ($from, $to) = @_;
    # Note that $to can be a directory or a file. If $to is a directory, File::Spec->splitpath($to)
    #  returns the parent directory of $to.
    my ( $volm, $path ) = File::Spec->splitpath($to);

    # TODO: Explore whether it's possible for $path to be Perl-false in
    # following line.  If not, remove.
    if ( $path && !-d $path ) {
        pathmk(File::Spec->catpath($volm, $path, ''));
    }

    if ( -l $from && $CopyLink ) {
        my $target = readlink( $from );
        # FCR: mass-untaint is OK since we have to allow what the file system does
        ($target) = $target =~ m/(.*)/;
        my $dest = _get_dest_path($from, $to);
        my $destdir = _parent_dir($dest);
        my $target_dest = _get_target_dest($target, $destdir);
        if (!-e $target) {
            warn "Copying a symlink ($from) whose target does not exist";
        }
        if (_relative_path($target) && $target_dest ne $target && !-e $target_dest) {
            warn "Copying a symlink ($from) with a relative target which does not exist";
        }
        if ( !-e $target_dest && _cygwin_strict_symlink_check() ) {
            warn "Cannot create a symlink whose target does not exists on OS=$^O";
        }
        unlink $dest if -l $dest;
        # Note: does not necessarily preserve the ownership of the symlink, to do that
        #  we would need to have access to the lchown (2) system call, see
        #  https://stackoverflow.com/a/420080/2173773  for more information.
        symlink( $target, $dest ) or return 0;
    }
    elsif (-d $from && -f $to) { return; }
    else {
        copy($from, $to) or return;

        my @base_file = File::Spec->splitpath( $from );
        my $mode_trg = -d $to ? File::Spec->catfile( $to, $base_file[$#base_file] ) : $to;

        chmod scalar((stat($from))[2]), $mode_trg;
    }
    return 1;
}

sub _relative_path {
    my ( $path ) = @_;

    return !File::Spec->file_name_is_absolute( $path);
}

sub _parent_dir {
    my ( $dir ) = @_;

    my ( $volm, $path, $file ) = File::Spec->splitpath($dir);
    return File::Spec->catpath($volm, $path);
}

# If $to is an existing directory, use it as the parent dir and extract the file name from the basename
#  of $from.  Else, assume $to is a file (not directory) and use it as the dest path.
sub _get_dest_path {
    my ( $from, $to ) = @_;

    return $to if !-d $to;
    my ( $volm, $path, $file ) = File::Spec->splitpath($from);
    return File::Spec->catfile($to, $file);
}

# Example: assume the current directory is /home/user/dir . Assume we want to copy a symlink file
#   fileA.txt in the current directory (absolute path = /home/user/dir/fileA.txt). Assume the target
#   of the symlink file (fileA.txt) is a relative path equal to $target = a/b/c/fileB.txt (since fileA.txt
#   is located in the current directory, this path is relative to /home/user/dir). Now we want to
#   copy the symlink file fileA.txt to e.g. $dest = d/e/f/fileB.txt (path is still relative to the
#   current directory). When copying a symlink with a relative target path, we want to keep the exact
#   relative path (we preserve the exact form of the target). It means that the new symlink will not
#   necessarily refer to fileB.txt in /home/user/dir/a/b/c anymore. To copy the symlink, we need to create
#   a new symlink file $dest with target $target relative to the directory where
#   fileB.txt is located. That is: relative to $destdir = dirname($dest). It means that the target of
#   fileB.txt becomes the file name $target_dest = d/e/f/a/b/c/fileA.txt relative to the current directory.
#
sub _get_target_dest {
    my ($target, $destdir) = @_;

    if (File::Spec->file_name_is_absolute( $target )) {
        return $target;
    }
    return File::Spec->catfile( $destdir, $target);
}

sub pathmk {
    my ( $vol, $dir, $file ) = File::Spec->splitpath( shift() );

    # TODO: Exploration whether $dir can be undef at this point.
    # If possible, then we should probably return immediately.
    if ( defined($dir) ) {
        my (@dirs) = File::Spec->splitdir($dir);

        for ( my $i = 0; $i < scalar(@dirs); $i++ ) {
            my $newdir = File::Spec->catdir( @dirs[ 0 .. $i ] );
            my $newpth = File::Spec->catpath( $vol, $newdir, "" );
            mkdir( $newpth );
            return unless -d $newpth;
        }
    }

    # TODO: Exploration whether $file can be undef at this point.
    # If possible, then we should probably return immediately.
    if ( defined($file) ) {
        my $newpth = File::Spec->catpath( $vol, $dir, $file );
        mkdir( $newpth );
        return unless -d $newpth;
    }

    return 1;
}


=head2 C<dircopy()>

=over 4

=item * Purpose

A stripped-down replacement for C<File::Copy::Recursive::dircopy()>.

Given the path to the directory specified by the first argument, the function
copies all of the files and directories beneath it to the directory specified
by the second argument.

=item * Arguments

    my $count = dircopy($orig, $new);
    warn "dircopy() returned undefined value" unless defined $count;

=item * Return Value

Upon completion, returns the count of directories and files created -- which
might be C<0>.

Should the function not complete (but not C<die>), an undefined value will be
returned.  That generally indicates problems with argument validation.  This
approach is taken for consistency with C<File::Copy::Recursive::dircopy()>.

In list context the return value is a one-item list holding the same value as
returned in scalar context.  The three-item list return value of
C<File::Copy::Recursive::dircopy()> is not supported.

=item * Restrictions

None of C<File::Copy::Recursive::dircopy>'s bells and whistles.  No guaranteed
preservation of file or directory modes.  No restriction on maximum depth.  No
nothing; this is fine-tuned to the needs of Perl toolchain modules and their
test suites.

=back

=cut

sub dircopy {

    # I'm not supporting the buffer limitation, at this point I can insert a
    # check for the correct number of arguments:  2
    # FCR2 dircopy does not support buffer limit as third argument

    return unless @_ == 2;

    # Check the definedness and string inequality of the arguments now;
    # Failure to do it now means that if $_[0] is not defined, you'll get an
    # uninitalized value warning in the first line that calls 'substr' below.

    return unless _basic_samecheck(@_);

    # See local file globstar-investigation.pl
    # What the block above does is to trim the 'from' argument so that, if user
    # said 'dircopy(/path/to/directory/*, /path/to/copy)', the first argument
    # is effectively reduced to '/path/to/directory/' but inside $globstar is
    # set to true.  Have to see what impact of $globstar true is.

    return _dircopy(@_);
}

sub _dircopy {
    my $globstar = 0;
    my $_zero    = $_[0];
    my $_one     = $_[1];
    if ( substr( $_zero, ( 1 * -1 ), 1 ) eq '*' ) {
        $globstar = 1;
        $_zero = substr( $_zero, 0, ( length($_zero) - 1 ) );
    }

    # Note also that, in the above, $_[0] and $_[1], while assigned to
    # variables, are not shifted-in.  Hence they retain their original values.
    # TODO: Investigate whether replacing $_[1] from this point forward with a
    # 'my' variable would be harmful.

    # Both arguments must now be defined (though not necessarily true -- yet);
    # they can't be equal; they can't be "dev-ino" equal on non-Win32 systems.
    # Verify that.

    return unless _dev_ino_check( $_zero, $_[1] );

    if ( !-d $_zero || ( -e $_[1] && !-d $_[1] ) ) {
        $! = 20;
        return;
    }

    # If the second argument is not an already existing directory,
    # then, create that directory now (the top-level 'to').

    if ( !-d $_[1] ) {
        pathmk( $_[1] ) or return;
    }
    # If the second argument is an existing directory ...
    # ... $globstar false is the typical case, i.e., no '/*' at end of 2nd argument

    my $baseend = $_one;
    my $level   = 0;
    my $filen   = 0;
    my $dirn    = 0;
    my $cygstrict = _cygwin_strict_symlink_check();
    my @symlinks;
    my $recurs;    #must be my()ed before sub {} since it calls itself
    $recurs = sub {
        my ( $str, $end ) = @_;
        $filen++ if $end eq $baseend;
        $dirn++  if $end eq $baseend;

        # On each pass of the recursive coderef, create the directory in the
        # 2nd argument or return (undef) if that does not succeed

        mkdir( $end ) or return if !-d $end;
        $level++;

        opendir( my $str_dh, $str ) or return;
        my @entities = grep( $_ ne '.' && $_ ne '..', readdir($str_dh) );
        closedir $str_dh;

        for my $entity (@entities) {
            my ($entity_ut) = $entity =~ m{ (.*) }xms;
            my $from = File::Spec->catfile( $str, $entity_ut );
            my $to = File::Spec->catfile( $end, $entity_ut );
            if ( -l $from && $CopyLink ) {
                my $target = readlink($from);
                # mass-untaint is OK since we have to allow what the file system does
                ($target) = $target =~ m/(.*)/;
                my $dest = $to;
                my $destdir = _parent_dir($dest);
                my $target_dest = _get_target_dest($target, $destdir);
                if (!-e $target) {
                    warn "Copying a symlink ($from) whose target does not exist";
                }
                if ($cygstrict && _relative_path($target) && !-e $target_dest) {
                    # postpone creating symlink to after all non-symlink files
                    # has been copied. Then $target_dest might have been created.
                    push @symlinks, [$target, $dest];
                }
                else {
                    unlink $dest if -l $dest;
                    symlink( $target, $dest ) or return;
                }
            }
            elsif ( -d $from ) {
                my $rc;
                $rc = $recurs->( $from, $to );
                return unless $rc;
                $filen++;
                $dirn++;
            }
            else {
                fcopy( $from, $to ) or return;
                $filen++;
            }
        } # End 'for' loop around @entities
        $level--;
        1;

    }; # END definition of $recurs

    $recurs->( $_zero, $_one ) or return;
    if ( $cygstrict ) {
        for my $link (@symlinks) {
            my ($target, $dest ) = @$link;
            my $destdir = _parent_dir($dest);
            my $target_dest = _get_target_dest($target, $destdir);
            if ( !-e $target_dest ) {
                warn "Cannot create a symlink whose target does not exists on OS=$^O";
            }
            unlink $dest if -l $dest;
            symlink( $target, $dest ) or return;
        }
    }
    return $filen;
}

sub _basic_samecheck {
    my ($from, $to) = @_;
    return if !defined $from || !defined $to;
    return if $from eq $to;
    return 1;
}

sub _dev_ino_check {
    my ($from, $to) = @_;
    return 1 if $^O =~ /^(?:cygwin|msys|MSWin32)$/;

    # perldoc perlport: "(Win32) "dev" and "ino" are not meaningful."
    # Will probably have to add restrictions for VMS and other OSes.
    my $one = join( '-', ( stat $from )[ 0, 1 ] ) || '';
    my $two = join( '-', ( stat $to   )[ 0, 1 ] ) || '';
    if ( $one and $one eq $two ) {
        warn "$from and $to are identical";
        return;
    }
    return 1;
}

=head2 C<rcopy()>

=over 4

=item * Purpose

A stripped-down replacement for C<File::Copy::Recursive::rcopy()>.  As is the
case with that FCR function, C<rcopy()> is more or less a wrapper around
C<fcopy()> or C<dircopy()>, depending on the nature of the first argument.

=item * Arguments

    rcopy($orig, $new) or die $!;

List of two required arguments:

=over 4

=item * Absolute path to the entity (file or directory) being copied; and

=item * Absolute path to the location to which the entity is being copied.

=back

=item * Return Value

Returns C<1> upon success; C<0> upon failure.  Returns an undefined value if,
for example, function cannot validate arguments.

=item * Comment

Please read the documentation for C<fcopy()> or C<dircopy()>, depending on the
nature of the first argument.

=back

=cut

sub rcopy {
    return unless @_ == 2;
    my ($from, $to) = @_;
    return unless _basic_samecheck($from, $to);

    # TODO:  Explore whether we should check (-e $from) here.
    # If we don't have a starting point, it shouldn't make any sense to go
    # farther.

    return unless _dev_ino_check($from, $to);

    # symlinks not yet supported
    #return if -l $_[0];
    goto &fcopy if -l $_[0] && $CopyLink;

    goto &_dircopy if -d $_[0] || substr( $_[0], ( 1 * -1 ), 1 ) eq '*';
    goto &_fcopy;
}

# Some information about symlinks on MSYS2 and Cygwin. Tested on Windows 10.
#
# Starting with Windows 10 Insiders build 14972, native symlinks can be created
#   without needing to elevate the console as administrator, see
#   https://blogs.windows.com/windowsdeveloper/2016/12/02/symlinks-windows-10/
#
#   To enable this feature, go to "Windows Security" -> "For developers",
#   and turn on "Developer mode".
#
# Before Windows 10 Insiders build 14972, native symlinks could still be created but needed
#  an elevated CMD console.
#
# [[ Note: It is possible to query (from e.g. perl) if developer mode is activated by investigating
#  the registry key SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock ]]
#
# How is this implemented in MSYS2 and in Cygwin? (TODO: Only tested on my current
#   Windows 10 Home, 21H1. Does it work similarly on older windows machines?)
#
# The behavior of the "ln --symbolic <target> <destination>" command in Cygwin depends
#   on the environment variable CYGWIN, see
#
#   https://cygwin.com/cygwin-ug-net/using-cygwinenv.html
#
#   The CYGWIN environment variable is used to configure many global settings for the Cygwin
#   runtime system. It contain options separated by blank characters. The option that is important
#   for the "ln -s" command is called "winsymlinks". According to the linked page above,
#   there are four cases for the winsymlinks option to consider:
#
# 1. winsymlinks is not defined. (Note: this behavior differs from that of MSYS2, see below).
#    This is called the default behavior for Cygwin.
#  a) If native symlinks are enabled, see above, then this is equivalent to setting
#    winsymlinks to "native" (e.g. CYGWIN="winsymlinks:native"), see 3) below.
#  b) If native symlinks are not enabled, this is equivalent to setting winsymlinks to "lnk"
#     see 2) below.
#
# 2. winsymlinks='' or winsymlinks=lnk
#   Whether <target> exists or not, "ln -s" creates <destination> as a Windows shortcut file
#     with a special header and the R/O attribute set.
#
# 3. winsymlinks=native
#    a) If native symlinks are enabled, and whether <target> exists or not, creates <destination> as
#       a native Windows symlink. Note, this is most similar to the behavior of "ln -s" on *nix.
#    b) If native symlinks are not enabled, it is equivalent to setting winsymlinks to "lnk",
#       see 2) above.
#
# 4. winsymlinks=nativestrict
#  a) If native symlinks are enabled and <target> exists, creates <destination> as a native Windows symlink,
#  b) else if native symlinks are not enabled or if <target> does not exist, "ln -s" fails.
#
#
#   Similiarly to the CYGWIN environment variable, the MSYS2 environment variable is used to
#   configure global settings for the MSYS2 runtime system (since MSYS2 are based on Cygwin). The
#   four cases for the winsymlinks option to consider is:
#
# 1. winsymlinks is not defined. The default behavior for MSYS2. (Note: this is not similar to Cygwin)
#  a) If <target> exists, <target> is (surprise!!) copied to <destination>, so <destination>
#     does not become a symlink but simply a copy of <target>, this happens whether
#     <target> is a file or a directory, or whether native symlinks are enabled or not. See
#
#   https://github.com/msys2/MSYS2-packages/issues/249
#
#  for more information.
#
#  b) If <target> does not exist, "ln -s" fails.
#
# 2. winsymlinks='' or winsymlinks=lnk
#   (Similar to Cygwin, see above)
#
# 3. winsymlinks=native
#   (Similar to Cygwin, see above)
#
# 4. winsymlinks=nativestrict
#   (Similar to Cygwin, see avove)
#
# Next question: How does the MSYS2 and CYGWIN environment variables afffect perl?
#
#  First thing:
#  - On both MSYS2 and Cygwin,
#
#       perl -MConfig -E'say $Config{d_symlink}'
#
#    prints "define".
#
#  - On regular windows ($^O eq "MSWin32") with e.g. strawberry perl, $Config{d_symlink}
#   -- is not defined for perl versions < 5.33.5
#   -- is defined for perl versions >= 5.33.5, see
#    https://metacpan.org/release/CORION/perl-5.33.5/view/pod/perldelta.pod#Windows
#
#  So the perl symlink function "works" on MSYS2 and Cygwin, and for newer versions of MSWin32.
#
#  For the further discussion below, consider the perl statement:
#
#   symlink $target, $dest;
#
#  If $dest exists, the symlink command always fail (returning a value of 0 and setting $!).
#  So consider the case where $dest does not exist:
#  There are four cases for the winsymlinks option contained in the MSYS or CYGWIN env. variable
#  to consider, as above for the "ln -s" command. It turns out that symlink behaves identically to
#  "ln -s" command, and when "ln -s" fails, symlink also fails and returns a value of 0 and sets $! (ERRNO).
#
#  Also note that the environment variable MSYS or CYGWIN cannot/should not be changed from within the
#  perl script itself. I am not sure why this does not work, but I tested it and it showed undefined
#  behavior in my tests. So the variables should be set before perl is run, e.g. on the command line:
#
#   MSYS=winsymlinks:native perl p.pl
#
# What about the perl "-l" operator ? Tests show that it does not differentiate between a Windows shortcut
#  file and a native symlink file. So
#
#    say "symlink" if -l "foobar";
#
# prints "symlink" for both file types. Further, there seems to be no tool available to determine which
#  of the two file types a given symlink file is. Note that there is a cygwin command readshortcut.exe
#  that can be used to read a shortcut file (with .lnk extension).
#
# So when we try to copy a symlink file, it is difficult to determine if the destination should be
#   a native symlink or a windows shortcut. The user would probably expect that the destination is the
#   same type of symlink as the source was. Note that even the "cp" command in MSYS2
#
#   cp -a source destination
#
# does in fact in general _not_ preserve the symlink type (tested), instead the destination symlink
# type is determined by the MSYS2 winsymlinks option (and not the symlink type of the source).
#
sub _cygwin_strict_symlink_check {
    return   _cygwin_strict_symlink_check_general("msys")
          || _cygwin_strict_symlink_check_general("cygwin");
}

# Checks if creating a broken symlink will fail. Note that for the case where winsymlinks is equals to
#  nativestrict (se 4. above), symlink will also fail to create a symlink that is not broken if
#  the parent console is not run with admin privileges or if developer mode has not been switched on
#  in the Windows Security settings.
sub _cygwin_strict_symlink_check_general {
    my ( $os ) = @_;
    my $OS = uc $os;
    if ($^O eq $os) {
        if (!defined $ENV{$OS} || $ENV{$OS} !~ /(?:^|\s+)winsymlinks/) {
            if ($^O eq 'msys') {
                if (defined $ENV{FILE_COPY_RECURSIVE_COPY_SYMLINK}) {
                    #warn "symlink not supported, copying file instead";
                    return 1;
                }
            }
            else {
                die "Cannot create symlink. Please set the en winsymlinks option in the MSYS environment "
                   . "variable to lnk, native, or nativestrict. Or alternatively, instead of creating a "
                   . "symlink, a regular file that is a copy of the symlink target can be created. "
                   . "To enable this option keep winsymlinks undefined and also set the "
                   . "environment variable FILE_COPY_RECURSIVE_COPY_SYMLINK to a defined value.";
            }
            return 0;
        }
        if ($ENV{$OS} =~ /(?:^|\s+)winsymlinks(?::lnk)?(?:\s+|$)/) {
            warn "Creating symlink as a Windows shortcut file";
            return 0;
        }
        elsif ($ENV{$OS} =~  /(?:^|\s+)\Qwinsymlinks:native\E(?:$|\s+)/) {
            return 0;
        }
        elsif ($ENV{$OS} =~  /(?:^|\s+)\Qwinsymlinks:nativestrict\E(?:$|\s+)/) {
            return 1;
        }
    }
    return 0;
}

=head2 File::Copy::Recursive Subroutines Not Supported in File::Copy::Recursive::Reduced

As of the current version, FCR2 has no publicly documented, exportable subroutines equivalent
to the following FCR exportable subroutines:

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

Notwithstanding the fact that this distribution is being released to address
certain problems in File-Copy-Recursive, credit must be given to FCR author
L<Daniel Muey|http://www.cpan.org/authors/id/D/DM/DMUEY/> for ingenious
conception and execution.  The implementation of the subroutines provided by
FCR2 follows that found in FCR to a significant extent.

Thanks also to Tom Hukins for supplying the patch which corrects FCR's
problems and which has been incorporated into FCR2 as well.

Hakon Hagland spotted problems on Cygwin and MSYS2 and supplied a pull request
which was further refined and applied.

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

