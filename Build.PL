#!/usr/bin/perl
use warnings;
use strict;

use Module::Build;

Module::Build->new(
    module_name => 'Bot::BasicBot::Slavorg',
    license => 'perl',
    requires => {
      'Bot::BasicBot' => 0.5,
      'YAML' => 0.1,
      'Test::More'          => '0.01',
    },
    create_makefile_pl => 'traditional',
    create_readme => 1,
)->create_build_script;

