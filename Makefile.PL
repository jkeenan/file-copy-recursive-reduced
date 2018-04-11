

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'File::Copy::Recursive::Reduced',
    VERSION_FROM => 'lib/File/Copy/Recursive/Reduced.pm', # finds \$VERSION
    AUTHOR       => 'James E Keenan (jkeenan@cpan.org)',
    ABSTRACT     => 'Recursive copying of files and directories within Perl 5 toolchain',
    PREREQ_PM    => {
                     'Test::Simple' => 0.44,
                    },
);
