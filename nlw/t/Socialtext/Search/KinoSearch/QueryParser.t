#!/usr/bin/env perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Socialtext tests => 7;

use_ok("Socialtext::Search::KinoSearch::QueryParser");

my $parser = new Socialtext::Search::KinoSearch::QueryParser();

my $query = $parser->munge_raw_query_string('tag:welcome');
is $query, 'tag:welcome';

$query = $parser->munge_raw_query_string('tag: welcome');
is $query, 'tag:welcome';

$query = $parser->munge_raw_query_string('Tag:welcome');
is $query, 'tag:welcome';

$query = $parser->munge_raw_query_string('Tag: welcome');
is $query, 'tag:welcome';

$query = $parser->munge_raw_query_string('tag:   welcome');
is $query, 'tag:welcome';

$query = $parser->munge_raw_query_string('Tag:   welcome');
is $query, 'tag:welcome';


