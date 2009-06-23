#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 9;
use Test::Socialtext::Search;
use Socialtext::Search::AbstractFactory;

fixtures(qw( admin no-ceq-jobs ));

my $hub = Test::Socialtext::Search::hub();

Socialtext::Search::AbstractFactory->GetFactory->create_indexer('admin')
    ->index_page('quick_start');

# fast
do_searches();

# search for number (plucene simple no index numbers)
search_for_term('1', 'negate');
exit;


sub do_searches {
    # test for a simple entry
    search_for_term('the');
    # test the "AND"ing of terms
    search_for_term('the impossiblesearchterm', 'negate');
}
