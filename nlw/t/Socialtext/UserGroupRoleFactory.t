#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use mocked 'Socialtext::Events', qw(clear_events event_ok is_event_count);
use Test::Socialtext tests => 43;
use Test::Exception;

###############################################################################
# Fixtures: db
# - need a DB, don't care what's in it
fixtures(qw( db ));

use_ok 'Socialtext::UserGroupRoleFactory';

###############################################################################
# TEST: get a Factory instance
get_factory_instance: {
    # "new()" gets us a Factory
    my $instance_one = Socialtext::UserGroupRoleFactory->new();
    isa_ok $instance_one, 'Socialtext::UserGroupRoleFactory';

    # "instance()" gets us a Factory
    my $instance_two = Socialtext::UserGroupRoleFactory->instance();
    isa_ok $instance_two, 'Socialtext::UserGroupRoleFactory';

    # its the *same* Factory
    is $instance_one, $instance_two, '... and its the same Factory';
}

###############################################################################
# TEST: create a new UGR, retrieve from DB
create_ugr: {
    my $user  = create_test_user();
    my $group = create_test_group();
    my $role  = Socialtext::Role->new(name => 'guest');

    # create the UGR, make sure it got created with our info
    clear_events();
    my $ugr   = Socialtext::UserGroupRoleFactory->Create( {
        user_id  => $user->user_id,
        group_id => $group->group_id,
        role_id  => $role->role_id,
    } );
    isa_ok $ugr, 'Socialtext::UserGroupRole', 'created UGR';
    is $ugr->user_id,  $user->user_id,   '... with provided user_id';
    is $ugr->group_id, $group->group_id, '... with provided group_id';
    is $ugr->role_id,  $role->role_id,   '... with provided role_id';

    # and that an Event was recorded
    event_ok(
        event_class => 'group',
        action      => 'create_role',
    );

    # double-check that we can pull this UGR from the DB
    my $queried = Socialtext::UserGroupRoleFactory->GetUserGroupRole(
        user_id  => $user->user_id,
        group_id => $group->group_id,
    );
    isa_ok $queried, 'Socialtext::UserGroupRole', 'queried UGR';
    is $queried->user_id,  $user->user_id,   '... with expected user_id';
    is $queried->group_id, $group->group_id, '... with expected group_id';
    is $queried->role_id,  $role->role_id,   '... with expected role_id';
}

###############################################################################
# TEST: create an UGR with a default Role
create_ugr_with_default_role: {
    my $user  = create_test_user();
    my $group = create_test_group();

    my $ugr   = Socialtext::UserGroupRoleFactory->Create( {
        user_id  => $user->user_id,
        group_id => $group->group_id,
    } );
    isa_ok $ugr, 'Socialtext::UserGroupRole', 'created UGR';
    is $ugr->role_id, Socialtext::UserGroupRoleFactory->DefaultRoleId(),
        '... with default role_id';
}

###############################################################################
# TEST: create a duplicate UGR
create_duplicate_ugr: {
    my $user  = create_test_user();
    my $group = create_test_group();

    # create the UGR
    my $ugr   = Socialtext::UserGroupRoleFactory->Create( {
        user_id  => $user->user_id,
        group_id => $group->group_id,
        } );
    isa_ok $ugr, 'Socialtext::UserGroupRole', 'created UGR';

    # create a duplicate UGR
    dies_ok {
        my $dupe = Socialtext::UserGroupRoleFactory->Create( {
            user_id  => $user->user_id,
            group_id => $group->group_id,
        } );
    } 'creating a duplicate record dies.';
}

###############################################################################
# TEST: update a UGR
update_a_ugr: {
    my $user        = create_test_user();
    my $group       = create_test_group();
    my $member_role = Socialtext::Role->new(name => 'member');
    my $guest_role  = Socialtext::Role->new(name => 'guest');
    my $factory     = Socialtext::UserGroupRoleFactory->instance();

    # create the UGR
    my $ugr   = $factory->Create( {
        user_id  => $user->user_id,
        group_id => $group->group_id,
        role_id  => $member_role->role_id,
        } );
    isa_ok $ugr, 'Socialtext::UserGroupRole', 'created UGR';

    # update the UGR
    clear_events();
    my $rc = $factory->Update($ugr, { role_id => $guest_role->role_id } );
    ok $rc, 'updated UGR';
    is $ugr->role_id, $guest_role->role_id, '... with updated role_id';

    # and that an Event was recorded
    event_ok(
        event_class => 'group',
        action      => 'update_role',
    );

    # make sure the updates are reflected in the DB
    my $queried = $factory->GetUserGroupRole(
        user_id  => $user->user_id,
        group_id => $group->group_id,
    );
    is $queried->role_id, $guest_role->role_id, '... which is reflected in DB';
}

###############################################################################
# TEST: ignores updates to "user_id" primary key
ignore_update_to_user_id_pkey: {
    my $user_one = create_test_user();
    my $user_two = create_test_user();
    my $group    = create_test_group();
    my $factory  = Socialtext::UserGroupRoleFactory->instance();

    # create the UGR
    my $ugr   = $factory->Create( {
        user_id  => $user_one->user_id,
        group_id => $group->group_id,
        } );
    isa_ok $ugr, 'Socialtext::UserGroupRole', 'created UGR';

    # update the UGR
    clear_events();
    my $rc = $factory->Update($ugr, { user_id => $user_two->user_id } );
    ok $rc, 'updated UGR';
    is $ugr->user_id, $user_one->user_id, '... UGR has original user_id';

    # and that *NO* Event was recorded
    is_event_count(0);
}

###############################################################################
# TEST: ignores updates to "group_id" primary key
ignore_update_to_group_id_pkey: {
    my $user      = create_test_user();
    my $group_one = create_test_group();
    my $group_two = create_test_group();
    my $factory   = Socialtext::UserGroupRoleFactory->instance();

    # create the UGR
    my $ugr   = $factory->Create( {
        user_id  => $user->user_id,
        group_id => $group_one->group_id,
        } );
    isa_ok $ugr, 'Socialtext::UserGroupRole', 'created UGR';

    # update the UGR
    clear_events();
    my $rc = $factory->Update($ugr, { group_id => $group_two->group_id } );
    ok $rc, 'updated UGR';
    is $ugr->group_id, $group_one->group_id, '... UGR has original group_id';

    # and that *NO* Event was recorded
    is_event_count(0);
}

###############################################################################
# TEST: update a non-existing UGR
update_non_existing_ugr: {
    my $ugr = Socialtext::UserGroupRole->new( {
        user_id  => 987654321,
        group_id => 987654321,
        role_id  => 987654321,
        } );
    isa_ok $ugr, 'Socialtext::UserGroupRole';

    # Updating a non-existing UGR fails silently; it *looks like* it was ok,
    # but nothing actually got updated in the DB.
    #
    # This mimics the behaviour of ST::User and for ST::UserWorkspaceRole.
    clear_events();
    lives_ok {
        Socialtext::UserGroupRoleFactory->Update(
            $ugr,
            { role_id => Socialtext::UserGroupRoleFactory->DefaultRoleId() },
        );
    } 'updating an non-existing UGR lives (but updates nothing)';

    # and that *NO* Event was recorded
    is_event_count(0);
}

###############################################################################
# TEST: delete an UGR
delete_ugr: {
    my $user    = create_test_user();
    my $group   = create_test_group();
    my $factory = Socialtext::UserGroupRoleFactory->instance();

    # create the UGR
    my $ugr   = $factory->Create( {
        user_id  => $user->user_id,
        group_id => $group->group_id,
        } );
    isa_ok $ugr, 'Socialtext::UserGroupRole', 'created UGR';

    # delete the UGR
    clear_events();
    my $rc = $factory->Delete($ugr);
    ok $rc, 'deleted the UGR';

    # and that an Event was recorded
    event_ok(
        event_class => 'group',
        action      => 'delete_role',
    );

    # make sure the delete was reflected in the DB
    my $queried = $factory->GetUserGroupRole(
        user_id  => $user->user_id,
        group_id => $group->group_id,
    );
    ok !$queried, '... which is reflected in DB';
}

###############################################################################
# TEST: delete a non-existing UGR
delete_non_existing_ugr: {
    my $ugr = Socialtext::UserGroupRole->new( {
        user_id  => 987654321,
        group_id => 987654321,
        role_id  => 987654321,
        } );
    isa_ok $ugr, 'Socialtext::UserGroupRole';

    # Deleting a non-existing UGR fails, without throwing an exception
    clear_events();
    my $factory = Socialtext::UserGroupRoleFactory->instance();
    my $rc      = $factory->Delete($ugr);
    ok !$rc, 'cannot delete a non-existing UGR';

    # and that *NO* Event was recorded
    is_event_count(0);
}
