#!/usr/bin/env perl

use strict;
use warnings;

die "Usage: perl retrieve.pl <paste_URI_or_ID>\n"
    unless @ARGV;

my $ID = shift;

use lib '../lib';
use WWW::Rafb::Retrieve;

my $paster = WWW::Rafb::Retrieve->new;

my $results_ref = $paster->retrieve( $ID )
    or die $paster->error;

printf "Paste %s was posted by %s\nDescription: %s\n%s\n",
            $paster->uri, @$results_ref{ qw( name  desc  content ) };