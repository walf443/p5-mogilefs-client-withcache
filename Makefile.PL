use inc::Module::Install;
use Module::Install::ReadmeFromPod;
name 'MogileFS-Client-WithCache';
all_from 'lib/MogileFS/Client/WithCache.pm';
readme_from 'lib/MogileFS/Client/WithCache.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

requires 'MogileFS::Client';

build_requires 'Test::More';
build_requires 'Module::Install::ReadmeFromPod';
use_test_base;
auto_include;
WriteAll;
