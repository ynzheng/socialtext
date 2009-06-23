#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 9;
use Test::Socialtext::Search;
use Socialtext::Search::AbstractFactory;

###############################################################################
# Fixtures: clean admin no-ceq-jobs
# - start with a clean slate; we expect only *one* page to be indexed
# - need a workspace to work with
# - but want no Ceq jobs, so *WE* control what gets indexed
fixtures(qw( clean admin no-ceq-jobs ));

###############################################################################
# We only want this *ONE* Page indexed, not the whole WS.
Socialtext::Search::AbstractFactory->GetFactory->create_indexer('admin')
    ->index_page('quick_start');

# test for a simple entry
search_for_term('the');

# test the "AND"ing of terms
search_for_term('the impossiblesearchterm', 'negate');

# search for number (plucene simple no index numbers)
search_for_term('1', 'negate');
