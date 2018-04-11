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
        File::Copy      => 0,
        File::Spec      => 0,
        Test::Deep      => 0,
        Test::File      => 0,
        File::Temp      => 0,
        Test::Warn      => 0,
        File::Glob      => 0,
        Test::Exception => 0,
        Cwd             => 0,
        File::Spec      => 0,
        Path::Tiny      => 0,
        Capture::Tiny      => 0,
                    },
    (
        $] >= 5.005
        ? (
            AUTHOR        => 'James E Keenan',
          )
        : ()
    ),
);
