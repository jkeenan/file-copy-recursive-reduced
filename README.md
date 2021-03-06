# README for Perl extension File-Copy-Recursive-Reduced

File-Copy-Recursive-Reduced is a Perl library which provides subroutines
exported on request which are intended to serve as drop-in replacements for
certain subroutines found in CPAN distribution
[File-Copy-Recursive](http://search.cpan.org/~dmuey/File-Copy-Recursive-0.40/)
(FCR).

## What Problem Does This Library Address?

As of early April 2018, FCR was failing to install on several important
operating systems including FreeBSD and Windows.  As a consequence, other CPAN
distributions which had a direct or indirect dependency on FCR (_e.g._,
CPAN-Reporter, DateTime, Dist-Zilla) were failing to install on those
platforms as well.

Such failures were "silent" in the sense that CPANtesters installations
generate no report authors when a distribution's upstream dependencies fail to
install.  No report to the CPANtesters database means no email notification to
CPAN authors.  So many authors were unaware that their distributions were
failing to install on important platforms.

Uncertainty as to when FCR would be fixed led to the creation of
File-Copy-Recursive-Reduced (FCR2).  Certain CPAN distributions adopted it
in place of FCR.  With the April 19 2018 release of FCR version 0.41, the
problems that motivated the creation of FCR2 have been addressed.

FCR2 is now feature-complete.  It exports three functions on demand which are
substantially equivalent to their FCR equivalents:

- `fcopy()`
- `dircopy()`
- `rcopy()`

After installation, call `perldoc File::Copy::Recursive::Reduced` for more
usage details.

These functions are quite appropriate in situations such as test suites where
the user has full knowledge of the files, directories and symlinks to be
recursively copied and does not need to manipulate the environment by setting
localized versions of FCR's package global variables.

## Install

This library can be installed in the customary way, _i.e.,_ by a CPAN
installer program such as `cpan` or `cpanm` or by satisfying its
prerequisites (Capture::Tiny and Path::Tiny, for the test suite only) and then
calling:

    perl Makefile.PL
    make
    make test
    make install

For further information, after installation call `perldoc
File::Copy::Recursive::Reduced`.
