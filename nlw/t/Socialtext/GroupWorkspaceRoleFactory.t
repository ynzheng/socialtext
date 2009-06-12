#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use mocked 'Socialtext::Events', qw(clear_events event_ok is_event_count);
use mocked 'Socialtext::Log', qw(:tests);
use Test::Socialtext tests => 80;
use Test::Exception;

###############################################################################
# Fixtures: db
# - need a DB, don't care what's in it
fixtures(qw( db ));

use_ok 'Socialtext::GroupWorkspaceRoleFactory';

###############################################################################
# TEST: get a Factory instance
get_factory_instance: {
    # "new()" gets us a Factory
    my $instance_one = Socialtext::GroupWorkspaceRoleFactory->new();
    isa_ok $instance_one, 'Socialtext::GroupWorkspaceRoleFactory';

    # "instance()" gets us a Factory
    my $instance_two = Socialtext::GroupWorkspaceRoleFactory->instance();
    isa_ok $instance_two, 'Socialtext::GroupWorkspaceRoleFactory';

    # its the *same* Factory
    is $instance_one, $instance_two, '... and its the same Factory';
}

###############################################################################
# TEST: create a new GWR, retrieve from DB
create_gwr: {
    my $user      = create_test_user();
    my $group     = create_test_group();
    my $workspace = create_test_workspace(user => $user);
    my $role      = Socialtext::Role->new(name => 'guest');

    # create the GWR, make sure it got created with our info
    clear_events();
    clear_log();
    my $gwr   = Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group->group_id,
        workspace_id => $workspace->workspace_id,
        role_id      => $role->role_id,
    } );
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole', 'created GWR';
    is $gwr->group_id, $group->group_id, '... with provided group_id';
    is $gwr->workspace_id, $workspace->workspace_id,
        '... with provided workspace_id';
    is $gwr->role_id, $role->role_id, '... with provided role_id';

    # and that an Event was recorded
    event_ok(
        event_class => 'workspace',
        action      => 'create_role',
    );

    # and that an entry was logged
    logged_like 'info', qr/ASSIGN,GROUP_WORKSPACE_ROLE/,
        '... creation was logged';

    # double-check that we can pull this GWR from the DB
    my $queried = Socialtext::GroupWorkspaceRoleFactory->GetGroupWorkspaceRole(
        group_id     => $group->group_id,
        workspace_id => $workspace->workspace_id,
    );
    isa_ok $queried, 'Socialtext::GroupWorkspaceRole', 'queried GWR';
    is $queried->group_id, $group->group_id, '... with expected group_id';
    is $queried->workspace_id, $workspace->workspace_id,
        '... with expected workspace_id';
    is $queried->role_id, $role->role_id, '... with expected role_id';
}

###############################################################################
# TEST: create an GWR with a default Role
create_gwr_with_default_role: {
    my $user  = create_test_user();
    my $ws    = create_test_workspace(user => $user);
    my $group = create_test_group();

    my $gwr   = Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group->group_id,
        workspace_id => $ws->workspace_id,
    } );
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole', 'created GWR';
    is $gwr->role_id, Socialtext::GroupWorkspaceRoleFactory->DefaultRoleId(),
        '... with default role_id';
}

###############################################################################
# TEST: create GWR with additional attributes
create_gwr_with_additional_attributes: {
    my $user  = create_test_user();
    my $ws    = create_test_workspace(user => $user);
    my $group = create_test_group();

    # GWR gets created, and we don't die a horrible death due to unknown extra
    # additional attributes
    my $gwr;
    lives_ok sub {
        $gwr   = Socialtext::GroupWorkspaceRoleFactory->Create( {
            group_id     => $group->group_id,
            workspace_id => $ws->workspace_id,
            bogus        => 'attribute',
        } );
    }, 'created GWR when additional attributes provided';
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole', '... created GWR';
}

###############################################################################
# TEST: create a duplicate GWR
create_duplicate_gwr: {
    my $user  = create_test_user();
    my $ws    = create_test_workspace(user => $user);
    my $group = create_test_group();

    # create the GWR
    my $gwr   = Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group->group_id,
        workspace_id => $ws->workspace_id,
        } );
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole', 'created GWR';

    # create a duplicate GWR
    dies_ok {
        my $dupe = Socialtext::GroupWorkspaceRoleFactory->Create( {
            group_id     => $group->group_id,
            workspace_id => $ws->workspace_id,
        } );
    } 'creating a duplicate record dies.';
}

###############################################################################
# TEST: update a GWR
update_a_gwr: {
    my $user        = create_test_user();
    my $ws          = create_test_workspace(user => $user);
    my $group       = create_test_group();
    my $member_role = Socialtext::Role->new(name => 'member');
    my $guest_role  = Socialtext::Role->new(name => 'guest');
    my $factory     = Socialtext::GroupWorkspaceRoleFactory->instance();

    # create the GWR
    my $gwr   = $factory->Create( {
        group_id     => $group->group_id,
        workspace_id => $ws->workspace_id,
        role_id      => $member_role->role_id,
        } );
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole', 'created GWR';

    # update the GWR
    clear_events();
    clear_log();
    my $rc = $factory->Update($gwr, { role_id => $guest_role->role_id } );
    ok $rc, 'updated GWR';
    is $gwr->role_id, $guest_role->role_id, '... with updated role_id';

    # and that an Event was recorded
    event_ok(
        event_class => 'workspace',
        action      => 'update_role',
    );

    # and that an entry was logged
    logged_like 'info', qr/CHANGE,GROUP_WORKSPACE_ROLE/,
        '... update was logged';

    # make sure the updates are reflected in the DB
    my $queried = $factory->GetGroupWorkspaceRole(
        group_id     => $group->group_id,
        workspace_id => $ws->workspace_id,
    );
    is $queried->role_id, $guest_role->role_id, '... which is reflected in DB';
}

###############################################################################
# TEST: ignores updates to "group_id" primary key
ignore_update_to_group_id_pkey: {
    my $user      = create_test_user();
    my $ws        = create_test_workspace(user => $user);
    my $group_one = create_test_group();
    my $group_two = create_test_group();
    my $factory   = Socialtext::GroupWorkspaceRoleFactory->instance();

    # create the GWR
    my $gwr   = $factory->Create( {
        group_id     => $group_one->group_id,
        workspace_id => $ws->workspace_id,
        } );
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole', 'created GWR';

    # update the GWR
    clear_events();
    clear_log();
    my $rc = $factory->Update($gwr, { group_id => $group_two->group_id } );
    ok $rc, 'updated GWR';
    is $gwr->group_id, $group_one->group_id, '... GWR has original group_id';

    # and that *NO* Event was recorded
    is_event_count(0);

    # and that *NO* entry was logged
    logged_not_like 'info', qr/GROUP_WORKSPACE_ROLE/,
        '... NO update was logged';
}

###############################################################################
# TEST: ignores updates to "workspace_id" primary key
ignore_update_to_workspace_id_pkey: {
    my $user    = create_test_user();
    my $ws_one  = create_test_workspace(user => $user);
    my $ws_two  = create_test_workspace(user => $user);
    my $group   = create_test_group();
    my $factory = Socialtext::GroupWorkspaceRoleFactory->instance();

    # create the GWR
    my $gwr   = $factory->Create( {
        group_id     => $group->group_id,
        workspace_id => $ws_one->workspace_id,
        } );
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole', 'created GWR';

    # update the GWR
    clear_events();
    clear_log();
    my $rc = $factory->Update($gwr, { workspace_id => $ws_two->workspace_id } );
    ok $rc, 'updated GWR';
    is $gwr->workspace_id, $ws_one->workspace_id,
        '... GWR has original workspace_id';

    # and that *NO* Event was recorded
    is_event_count(0);

    # and that *NO* entry was logged
    logged_not_like 'info', qr/GROUP_WORKSPACE_ROLE/,
        '... NO update was logged';
}

###############################################################################
# TEST: update a non-existing GWR
update_non_existing_gwr: {
    my $gwr = Socialtext::GroupWorkspaceRole->new( {
        group_id     => 987654321,
        workspace_id => 987654321,
        role_id      => 987654321,
        } );
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole';

    # Updating a non-existing GWR fails silently; it *looks like* it was ok,
    # but nothing actually got updated in the DB.
    #
    # This mimics the behaviour of ST::User for ST::UserWorkspaceRole.
    clear_events();
    clear_log();
    lives_ok {
        Socialtext::GroupWorkspaceRoleFactory->Update(
            $gwr,
            { role_id => Socialtext::GroupWorkspaceRoleFactory->DefaultRoleId() },
        );
    } 'updating an non-existing GWR lives (but updates nothing)';

    # and that *NO* Event was recorded
    is_event_count(0);

    # and that *NO* entry was logged
    logged_not_like 'info', qr/GROUP_WORKSPACE_ROLE/,
        '... NO update was logged';
}

###############################################################################
# TEST: delete an GWR
delete_gwr: {
    my $user      = create_test_user();
    my $workspace = create_test_workspace(user => $user);
    my $group     = create_test_group();
    my $factory   = Socialtext::GroupWorkspaceRoleFactory->instance();

    # create the GWR
    my $gwr   = $factory->Create( {
        group_id     => $group->group_id,
        workspace_id => $workspace->workspace_id,
        } );
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole', 'created GWR';

    # delete the GWR
    clear_events();
    clear_log();
    my $rc = $factory->Delete($gwr);
    ok $rc, 'deleted the GWR';

    # and that an Event was recorded
    event_ok(
        event_class => 'workspace',
        action      => 'delete_role',
    );

    # and that an entry was logged
    logged_like 'info', qr/REMOVE,GROUP_WORKSPACE_ROLE/,
        '... removal was logged';

    # make sure the delete was reflected in the DB
    my $queried = $factory->GetGroupWorkspaceRole(
        group_id     => $group->group_id,
        workspace_id => $workspace->workspace_id,
    );
    ok !$queried, '... which is reflected in DB';
}

###############################################################################
# TEST: delete a non-existing GWR
delete_non_existing_gwr: {
    my $gwr = Socialtext::GroupWorkspaceRole->new( {
        group_id     => 987654321,
        workspace_id => 987654321,
        role_id      => 987654321,
        } );
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole';

    # Deleting a non-existing GWR fails, without throwing an exception
    clear_events();
    clear_log();
    my $factory = Socialtext::GroupWorkspaceRoleFactory->instance();
    my $rc      = $factory->Delete($gwr);
    ok !$rc, 'cannot delete a non-existing GWR';

    # and that *NO* Event was recorded
    is_event_count(0);

    # and that *NO* entry was logged
    logged_not_like 'info', qr/GROUP_WORKSPACE_ROLE/,
        '... NO removal was logged';
}

################################################################################
# TEST: ByGroupId 
by_group_id: {
    my $user   = create_test_user();
    my $ws_one = create_test_workspace(user => $user);
    my $ws_two = create_test_workspace(user => $user);
    my $group  = create_test_group();

    # Create GWRs
    Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group->group_id,
        workspace_id => $ws_one->workspace_id,
    } );

    Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group->group_id,
        workspace_id => $ws_two->workspace_id,
    } );

    my $workspaces = Socialtext::GroupWorkspaceRoleFactory->ByGroupId(
        $group->group_id
    );
    isa_ok $workspaces, 'Socialtext::MultiCursor', 'Got a list of results';
    is $workspaces->count(), 2, '... of correct size';

    my $q_ws_one = $workspaces->next();
    isa_ok $q_ws_one, 'Socialtext::GroupWorkspaceRole', 'First result';
    is $q_ws_one->workspace_id, $ws_one->workspace_id,
        '... with correct workspace_id';

    my $q_ws_two = $workspaces->next();
    isa_ok $q_ws_two, 'Socialtext::GroupWorkspaceRole', 'Second result';
    is $q_ws_two->workspace_id, $ws_two->workspace_id,
        '... with correct workspace_id';
}

################################################################################
# TEST: ByGroupId -- passing in a closure.
by_group_id_with_closure: {
    my $user   = create_test_user();
    my $ws_one = create_test_workspace(user => $user);
    my $ws_two = create_test_workspace(user => $user);
    my $group  = create_test_group();

    # Create GWRs
    Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group->group_id,
        workspace_id => $ws_one->workspace_id,
    } );

    Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group->group_id,
        workspace_id => $ws_two->workspace_id,
    } );

    my $workspaces = Socialtext::GroupWorkspaceRoleFactory->ByGroupId( 
        $group->group_id,
        sub { shift->workspace(); }
    );
    isa_ok $workspaces, 'Socialtext::MultiCursor', 'Got a list of results';
    is $workspaces->count(), 2, '... of correct size';

    my $q_ws_one = $workspaces->next();
    isa_ok $q_ws_one, 'Socialtext::Workspace', 'First result';
    is $q_ws_one->name, $ws_one->name, '... with correct name';

    my $q_ws_two = $workspaces->next();
    isa_ok $q_ws_two, 'Socialtext::Workspace', 'Second result';
    is $q_ws_two->name, $ws_two->name, '... with correct name';
}

################################################################################
# TEST: ByGroupId with non-existing group_id
by_group_id_with_non_existing_group_id: {
    my $gwrs = Socialtext::GroupWorkspaceRoleFactory->ByGroupId( 12345678 );

    isa_ok $gwrs, 'Socialtext::MultiCursor', 'Got a list';
    ok !$gwrs->count(), '... with no results';
}

###############################################################################
# TEST: ByWorkspaceId 
by_workspace_id: {
    my $user      = create_test_user();
    my $ws        = create_test_workspace(user => $user);
    my $group_one = create_test_group();
    my $group_two = create_test_group();

    # Create GWRs
    Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group_one->group_id,
        workspace_id => $ws->workspace_id,
    } );

    Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group_two->group_id,
        workspace_id => $ws->workspace_id,
    } );

    my $groups = Socialtext::GroupWorkspaceRoleFactory->ByWorkspaceId(
        $ws->workspace_id
    );
    isa_ok $groups, 'Socialtext::MultiCursor', 'Got a list';
    is $groups->count, 2, '... of correct size';

    my $q_group_one = $groups->next();
    isa_ok $q_group_one, 'Socialtext::GroupWorkspaceRole', 'Got first group';
    is $q_group_one->group_id, $group_one->group_id, '... with right group_id';

    my $q_group_two = $groups->next();
    isa_ok $q_group_two, 'Socialtext::GroupWorkspaceRole', 'Got second group';
    is $q_group_two->group_id, $group_two->group_id, '... with right group_id';
}

################################################################################
# TEST: ByWorkspaceId -- passing in a closure.
by_workspace_id_with_closure: {
    my $user      = create_test_user();
    my $ws        = create_test_workspace(user => $user);
    my $group_one = create_test_group();
    my $group_two = create_test_group();

    # Create GWRs
    Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group_one->group_id,
        workspace_id => $ws->workspace_id,
    } );

    Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group_two->group_id,
        workspace_id => $ws->workspace_id,
    } );

    my $groups = Socialtext::GroupWorkspaceRoleFactory->ByWorkspaceId( 
        $ws->workspace_id,
        sub { shift->group(); },
    );

    isa_ok $groups, 'Socialtext::MultiCursor', 'Got a list';
    is $groups->count, 2, '... of correct size';
    
    my $q_group_one = $groups->next();
    isa_ok $q_group_one, 'Socialtext::Group', 'Got first group';
    is $q_group_one->driver_group_name, $group_one->driver_group_name, 
        '... with right name';

    my $q_group_two = $groups->next();
    isa_ok $q_group_two, 'Socialtext::Group', 'Got second group';
    is $q_group_two->driver_group_name, $group_two->driver_group_name, 
        '... with right name';
}

################################################################################
# TEST: ByWorkspaceId with non-existing workspace_id
by_workspace_id_with_non_existing_workspace_id: {
    my $groups = Socialtext::GroupWorkspaceRoleFactory->ByWorkspaceId(
        123456789
    );

    isa_ok $groups, 'Socialtext::MultiCursor', 'Got a list';
    ok !$groups->count(), '... with no results';
}
