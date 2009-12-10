use inc::Module::Install;
name 'MogileFS-Client-WithCache';
all_from 'lib/MogileFS/Client/WithCache.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
