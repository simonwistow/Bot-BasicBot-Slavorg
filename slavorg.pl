#!/usr/bin/perl
use warnings;
use strict;
use lib 'lib';
use Bot::BasicBot::Slavorg;

Bot::BasicBot::Slavorg->new(
  nick => 'test_slavorg',
  config_file => "slavorg.yaml",
)->run();

