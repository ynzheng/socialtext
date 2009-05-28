#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 12;

###############################################################################
# Fixtures: db
# - need DB, but don't care what's in it
fixtures(qw( db ));

use_ok 'Socialtext::Group';

###############################################################################
# TEST: default Group Factories
default_group_factories_configuration: {
    my $is_default = Socialtext::AppConfig->is_default('group_factories');
    ok $is_default, 'default group_factories configuration';

    my @drivers  = Socialtext::Group->Drivers();
    my @expected = (qw(Default));
    is_deeply \@drivers, \@expected, '... one configured Group Factory';
}

###############################################################################
# TEST: parsing configured Group Factories list
configured_group_factories: {
    my $configured = 'Dummy:123;Default';

    Socialtext::AppConfig->set('group_factories', $configured);
    my $factories = Socialtext::AppConfig->group_factories();
    is $factories, $configured, 'custom group_factories configuration';

    my @drivers  = Socialtext::Group->Drivers();
    my @expected = (qw(Dummy:123 Default));
    is_deeply \@drivers, \@expected, '... two configured Group Factories';

    Socialtext::AppConfig->set('group_factories', 'Default');
}

###############################################################################
# TEST: query Groups by Account Id
query_groups_by_account_id: {
    my $account = create_test_account();

    # create some Groups, *not* in alphabetical order; so we know when we get
    # them back that they're not just returned in "the order they were stuffed
    # in", but are actually in a sorted order.
    my $group_one = create_test_group(
        account   => $account,
        unique_id => 'Group ZZZ',
    );
    my $group_two = create_test_group(
        account   => $account,
        unique_id => 'Group AAA',
    );

    # query the Groups in the Account and make sure we got them back in the
    # right order.
    my $groups = Socialtext::Group->ByAccountId(
        account_id => $account->account_id
    );
    isa_ok $groups, 'Socialtext::MultiCursor', 'got cursor of Groups';
    is $groups->count(), 2, '... containing two Groups';

    my $iter = $groups->next();
    isa_ok $iter, 'Socialtext::Group', '... first Group';
    is $iter->group_id, $group_two->group_id, '... ... which is Group AAA';

    $iter = $groups->next();
    isa_ok $iter, 'Socialtext::Group', '... second Group';
    is $iter->group_id, $group_one->group_id, '... ... which is Group ZZZ';

    $iter = $groups->next();
    ok !$iter, '... no more Groups';
}
