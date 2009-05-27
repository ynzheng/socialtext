#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 28;

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
# TEST: delete a Group object
delete_group: {
    my $factory = Socialtext::Group::Default::Factory->new();
    isa_ok $factory, 'Socialtext::Group::Default::Factory';

    # create a Group that we can monkey with
    my $account_id = Socialtext::Account->Socialtext->account_id();
    my $creator_id = Socialtext::User->SystemUser->user_id();
    my $group = $factory->Create( {
        driver_group_name   => 'Test Group',
        account_id          => $account_id,
        created_by_user_id  => $creator_id,
    } );
    isa_ok $group, 'Socialtext::Group::Default';

    # retrieve Group; it should be there
    my $queried = $factory->GetGroupHomunculus( group_id => $group->group_id );
    isa_ok $queried, 'Socialtext::Group::Homunculus', '... queried Homunculus';

    # delete Group
    ok $factory->Delete($queried), '... which can be deleted';

    # retrieve Group should return empty-handed
    $queried = $factory->GetGroupHomunculus( group_id => $group->group_id );
    ok !$queried, "... and which can't be queried after deletion";
}

###############################################################################
# TEST: cannot delete non-existent Group
delete_nonexistent_group: {
    my $factory = Socialtext::Group::Default::Factory->new();
    isa_ok $factory, 'Socialtext::Group::Default::Factory';

    # create a Group that we can monkey with
    my $account_id = Socialtext::Account->Socialtext->account_id();
    my $creator_id = Socialtext::User->SystemUser->user_id();
    my $group = $factory->Create( {
        driver_group_name   => 'Test Group',
        account_id          => $account_id,
        created_by_user_id  => $creator_id,
    } );
    isa_ok $group, 'Socialtext::Group::Default';

    # delete Group
    ok  $factory->Delete($group), '... which can be deleted';
    ok !$factory->Delete($group), '... ... but only once';
}

###############################################################################
# TEST: trying to delete a Group Record without Group Id throws error
delete_group_record_without_id: {
    my $factory = Socialtext::Group::Default::Factory->new();
    isa_ok $factory, 'Socialtext::Group::Default::Factory';

    my $rc = eval { $factory->DeleteGroupRecord() };
    ok !$rc, 'deleting Group record fails when no group_id';
    like $@, qr/must have a group_id/,
        '... throwing exception about no group_id';
}
