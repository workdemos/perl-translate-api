use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Speed::App',
    license             => 'perl',
    dist_author         => 'maxkerrer <maxkerrer@live.com>',
    dist_version_from   => 'lib/Speed/App.pm',
    requires => {
        'Test::More' => 0,
        'version'    => 0,
    },
    add_to_cleanup      => [ 'Speed-*' ],
);

$builder->create_build_script();
