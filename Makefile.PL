use 5.014;
use strict;
use warnings FATAL => 'all';
use inc::Module::Install;

name     'Lingua-EN-AutoReview';
all_from 'lib/Lingua/EN/AutoReview.pm';

tests_recursive('t');

resources (
   repository => 'git://github.com/RogerDodger/Lingua-EN-AutoReview.git',
);

configure_requires (
   'Module::Install' => 0,
);

build_requires (
   'Test::More' => 0,
);

requires (
   'Moose' => 0,
   'File::ShareDir' => 0,
   'Moose::Meta::Attribute::Native::Trait::Array' => 0,
);

install_share 'module', 'Lingua::EN::AutoReview', 'share';
install_script "script/autoreview.pl";

install_as_cpan;
auto_install;
WriteAll;
