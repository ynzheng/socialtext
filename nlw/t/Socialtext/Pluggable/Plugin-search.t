#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext tests => 2;
use Socialtext::Jobs;
use Socialtext::Search::AbstractFactory;

fixtures(qw( admin exchange no-ceq-jobs ));

my $hub = new_hub('admin');
Socialtext::Search::AbstractFactory->GetFactory->create_indexer('admin')
    ->index_workspace('admin');
ceqlotron_run_synchronously();

use_ok 'Socialtext::Pluggable::Plugin';

my $plug = Socialtext::Pluggable::Plugin->new;
$plug->{hub} = $hub;

#search
my $pages = $plug->search(search_term => 'tag:welcome');

# 'central_page_templates' maybe got removed?
my @expected = qw(
advanced_getting_around
can_i_change_something
central_page_important_links
congratulations_you_know_how_to_use_a_workspace
conversations
document_library_template
documents_that_people_are_working_on
expense_report_template
how_do_i_find_my_way_around
how_do_i_make_a_new_page
how_do_i_make_links
learning_resources
lists_of_pages
meeting_agendas
meeting_minutes_template
member_directory
people
project_plans
project_summary_template
quick_start
start_here
what_else_is_here
what_if_i_make_a_mistake
what_s_the_funny_punctuation
workspace_tour_table_of_contents
);

my @page_ids = sort map { $_->{page_id} } @{$pages->{rows}};
is_deeply \@page_ids, \@expected, "Tag search returned the right page results";
