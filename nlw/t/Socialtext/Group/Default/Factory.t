#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 24;

###############################################################################
# Fixtures: db
# - need a DB to work with, but don't care what's in it.
fixtures(qw( db ));

use_ok 'Socialtext::Group::Default::Factory';

###############################################################################
# TEST: instantiation, no parameters
instantiation_no_parameters: {
    my $factory = Socialtext::Group::Default::Factory->new();
    isa_ok $factory, 'Socialtext::Group::Default::Factory';
}

###############################################################################
# TEST: Default Group Factory *is* updateable
default_group_factory_is_updateable: {
    my $factory = Socialtext::Group::Default::Factory->new();
    isa_ok $factory, 'Socialtext::Group::Default::Factory';
    ok $factory->can_update_store(), '... and is updateable';
}

###############################################################################
# TEST: create a new Group object
create_group: {
    my $factory = Socialtext::Group::Default::Factory->new();
    isa_ok $factory, 'Socialtext::Group::Default::Factory';

    my $account_id = Socialtext::Account->Socialtext->account_id();
    my $creator_id = Socialtext::User->SystemUser->user_id();
    my $test_start = $factory->Now();
    my $group = $factory->Create( {
        driver_group_name   => 'Test Group',
        account_id          => $account_id,
        created_by_user_id  => $creator_id,
    } );
    my $test_finish = $factory->Now();
    isa_ok $group, 'Socialtext::Group::Default';

    # verify Group attributes
    ok $group->group_id,   '... has an assigned group_id';
    is $group->driver_key, $factory->driver_key,
        '... with driver_key matching factory';
    is $group->driver_name, $factory->driver_name,
        '... with driver_name matching factory';
    is $group->driver_id, $factory->driver_id,
        '... with driver_id matching factory';
    is $group->driver_unique_id, $group->group_id,
        '... group_id matches driver_unique_id (for Default Groups)';
    is $group->driver_group_name, 'Test Group',
        '... with driver_group_name matching provided Group Name';
    is $group->account_id, $account_id,
        '... with provided Account Id';
    is $group->created_by_user_id, $creator_id,
        '... with provided creator User Id';

    my $created_when = $group->creation_datetime;
    ok $created_when > $test_start,
        '... created after our test started';
    ok $created_when < $test_finish,
        '... ... and before our test finished (so we must have created it)';
}

###############################################################################
# TEST: retrieve previously created Group
retrieve_group: {
    my $account_id = Socialtext::Account->Socialtext->account_id();
    my $creator_id = Socialtext::User->SystemUser->user_id();
    my $group = Socialtext::Group->Create( {
        driver_group_name   => 'Test Group',
        account_id          => $account_id,
        creator_id          => $creator_id,
        } );
    isa_ok $group, 'Socialtext::Group', 'newly created group';

    my $retrieved = Socialtext::Group->GetGroup(group_id => $group->group_id);
    isa_ok $retrieved, 'Socialtext::Group', 'retrieved group';

    is $retrieved->group_id, $group->group_id,
        '... with matching group_id';
    is $retrieved->driver_key, $group->driver_key,
        '... with matching driver_key';
    is $retrieved->driver_group_name, $group->driver_group_name,
        '... with matching driver_group_name';
    is $retrieved->account_id, $group->account_id,
        '... with matching account_id';
    is $retrieved->created_by_user_id, $group->created_by_user_id,
        '... with matching created_by_user_id';
    is $retrieved->creation_datetime, $group->creation_datetime,
        '... with matching creation_datetime';
}
