#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 15;
use Socialtext::GroupWorkspaceRoleFactory;

###############################################################################
# Fixtures: db
# - need a DB, but don't care what's in it.
fixtures(qw( db ));

use_ok 'Socialtext::Workspace';

################################################################################
# NOTE: this behaviour is more extensively tested in
# t/Socialtext/GroupWorkspaceRoleFactory.t
################################################################################

################################################################################
# TEST: Workspace has no Groups with Roles in it
workspace_with_no_groups: {
    my $user      = create_test_user();
    my $workspace = create_test_workspace(user => $user);

    my $groups = $workspace->groups();

    isa_ok $groups, 'Socialtext::MultiCursor', 'got a list of Groups';
    is $groups->count(), 0, '... with the correct count';
}

################################################################################
# TEST: Workspace has some Groups with Roles in it
workspace_has_groups: {
    my $user      = create_test_user();
    my $workspace = create_test_workspace(user => $user);
    my $group_one = create_test_group();
    my $group_two = create_test_group();

    # Create GWRs, giving the Group a default Role
    # - we do this via GWR as we haven't tested the other helper methods yet
    Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group_one->group_id,
        workspace_id => $workspace->workspace_id,
    } );

    Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group_two->group_id,
        workspace_id => $workspace->workspace_id,
    } );

    my $groups = $workspace->groups();

    isa_ok $groups, 'Socialtext::MultiCursor', 'got a list of groups';
    is $groups->count(), 2, '... with the correct count';
    isa_ok $groups->next(), 'Socialtext::Group', '... queried Group';
}

################################################################################
# TEST: Add Group to Workspace with default Role
add_group_to_workspace_with_default_role: {
    my $user      = create_test_user();
    my $workspace = create_test_workspace(user => $user);
    my $group     = create_test_group();

    # Add the Group to the Workspace
    $workspace->add_group(group => $group);

    # Make sure the Group got added properly
    my $groups = $workspace->groups();
    is $groups->count(), 1, 'Group was added to Workspace';

    # Make sure Group was given the default Role
    my $default_role = Socialtext::GroupWorkspaceRoleFactory->DefaultRole();
    my $groups_role  = $workspace->role_for_group($group);
    is $groups_role->role_id, $default_role->role_id,
        '... with Default GWR Role'
}

###############################################################################
# TEST: Add Group to Workspace with explicit Role
add_group_to_workspace_with_role: {
    my $user      = create_test_user();
    my $workspace = create_test_workspace(user => $user);
    my $group     = create_test_group();
    my $role      = Socialtext::Role->Guest();

    # Add the Group to the Workspace
    $workspace->add_group(group => $group, role => $role);

    # Make sure the Group got added properly
    my $groups = $workspace->groups();
    is $groups->count(), 1, 'Group was added to Workspace';

    # Make sure Group has the correct Role
    my $groups_role  = $workspace->role_for_group($group);
    is $groups_role->role_id, $role->role_id, '... with provided Role'
}

###############################################################################
# TEST: Update Group's Role in Workspace
update_groups_role_in_workspace: {
    my $user      = create_test_user();
    my $workspace = create_test_workspace(user => $user);
    my $group     = create_test_group();
    my $role      = Socialtext::Role->Guest();

    # Add the Group to the Workspace, with Default Role
    $workspace->add_group(group => $group);

    # Make sure the Group was given the Default Role
    my $default_role = Socialtext::GroupWorkspaceRoleFactory->DefaultRole();
    my $groups_role  = $workspace->role_for_group($group);
    is $groups_role->role_id, $default_role->role_id,
        '... with Default UGR Role';

    # Update the Group's Role
    $workspace->add_group(group => $group, role => $role);

    # Make sure Group had their Role updated
    $groups_role = $workspace->role_for_group($group);
    is $groups_role->role_id, $role->role_id, '... with updated Role';
}

###############################################################################
# TEST: Get the Role for a Group
get_role_for_group: {
    my $user      = create_test_user();
    my $workspace = create_test_workspace(user => $user);
    my $group     = create_test_group();

    # Add the Group to the Workspace
    $workspace->add_group(group => $group);

    # Get the Role for the Group
    my $role = $workspace->role_for_group($group);
    isa_ok $role, 'Socialtext::Role', 'queried Role';
}

###############################################################################
# TEST: Does this Group have a Role in the Workspace
does_workspace_have_group: {
    my $user      = create_test_user();
    my $workspace = create_test_workspace(user => $user);
    my $group     = create_test_group();

    # Workspace should not (yet) have this Group
    ok !$workspace->has_group($group),
        'Group does not yet have Role in Workspace';

    # Add the Group to the Workspace
    $workspace->add_group(group => $group);

    # Now the Group is in the Workspace
    ok $workspace->has_group($group), '... but has now been added';
}
