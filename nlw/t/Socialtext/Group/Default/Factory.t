#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 16;

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
