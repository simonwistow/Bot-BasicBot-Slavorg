#!/usr/bin/perl
use warnings;
use strict;
use lib 'lib';
use Bot::BasicBot::Slavorg;

Bot::BasicBot::Slavorg->new(
  server => "london.irc.perl.org",
  nick => 'clunker2',
  config_file => "clunker.yaml",
)->run();

