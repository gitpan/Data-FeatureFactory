use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Data::FeatureFactory',
    AUTHOR              => 'Oldřich Krůza <Oldrich.Kruza@sixtease.net>',
    VERSION_FROM        => 'lib/Data/FeatureFactory.pm',
    ABSTRACT_FROM       => 'lib/Data/FeatureFactory.pm',
    PREREQ_PM           => {
        'Carp'           => 0,
        'Test::More'     => 0,
        'File::Basename' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Data-FeatureFactory-*' },
);
