#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 3;

###############################################################################
# Fixtures: db
# - need a DB, but don't care what's in it
fixtures(qw( db ));

###############################################################################
# TEST: a newly created Account has *no* Groups in it.
new_account_has_no_groups: {
    my $account = create_test_account();
    my $count   = $account->group_count();
    is $count, 0, 'newly created Account has no Groups in it';
}

###############################################################################
# TEST: Group count is correct
group_count_is_correct: {
    my $account = create_test_account();

    # add some Groups, make sure the count goes up
    my $group_one = create_test_group(account => $account);
    is $account->group_count(), 1, 'Account has one Group';

    my $group_two = create_test_group(account => $account);
    is $account->group_count(), 2, 'Account has two Groups';
}
