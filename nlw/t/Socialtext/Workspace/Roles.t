#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 28;

###############################################################################
# Fixtures: db
# - need a DB, but don't care what's in it
fixtures(qw( db ));

use_ok 'Socialtext::Workspace::Roles';

###############################################################################
# TEST: Get Users with a Role in a given Workspace
users_by_workspace_id: {
    my $system_user = Socialtext::User->SystemUser();
    my $workspace   = create_test_workspace(user => $system_user);
    my $user_one    = create_test_user();
    my $user_two    = create_test_user();
    my $group       = create_test_group();

    # One of the Users has an explicit Role in the Workspace
    $workspace->add_user(user => $user_one);

    # Another User has a Role in the Workspace via Group membership
    $group->add_user(user => $user_two);
    $workspace->add_group(group => $group);

    # Get the list of Users in the Workspace
    my $cursor = Socialtext::Workspace::Roles->UsersByWorkspaceId(
        workspace_id => $workspace->workspace_id,
    );
    isa_ok $cursor, 'Socialtext::MultiCursor', 'list of Users in WS';
    is $cursor->count(), 2, '... with correct number of Users';

    is $cursor->next->user_id, $user_one->user_id,
        '... ... first expected test User';
    is $cursor->next->user_id, $user_two->user_id,
        '... ... second expected test User';
}

###############################################################################
# TEST: Get Users with a Role in a given Workspace, when a User has _multiple_
# Roles in the WS
users_by_workspace_id_multiple_group_roles: {
    my $system_user = Socialtext::User->SystemUser();
    my $workspace   = create_test_workspace(user => $system_user);
    my $user        = create_test_user();
    my $group_one   = create_test_group();
    my $group_two   = create_test_group();

    # User has multiple Roles in the WS via Group memberships
    $group_one->add_user(user => $user);
    $workspace->add_group(group => $group_one);

    $group_two->add_user(user => $user);
    $workspace->add_group(group => $group_two);

    # Get the list of Users in the Workspace
    my $cursor = Socialtext::Workspace::Roles->UsersByWorkspaceId(
        workspace_id => $workspace->workspace_id,
    );
    isa_ok $cursor, 'Socialtext::MultiCursor', 'list of Users in WS';
    is $cursor->count(), 1, '... User only appears *ONCE* in the list';
    is $cursor->next->user_id, $user->user_id, '... ... expected test User';
}

###############################################################################
# TEST: Count Users with a Role in a given Workspace
count_users_by_workspace_id: {
    my $system_user = Socialtext::User->SystemUser();
    my $workspace   = create_test_workspace(user => $system_user);
    my $user_one    = create_test_user();
    my $user_two    = create_test_user();
    my $group       = create_test_group();

    # One of the Users has an explicit Role in the Workspace
    $workspace->add_user(user => $user_one);

    # Another User has a Role in the Workspace via Group membership
    $group->add_user(user => $user_two);
    $workspace->add_group(group => $group);

    # Get the count of Users in the Workspace
    my $count = Socialtext::Workspace::Roles->CountUsersByWorkspaceId(
        workspace_id => $workspace->workspace_id,
    );
    is $count, 2, 'WS has correct number of Users';
}

###############################################################################
# TEST: Get Users with a Role in a given Workspace, when a User has _multiple_
# Roles in the WS
count_users_by_workspace_id_multiple_group_roles: {
    my $system_user = Socialtext::User->SystemUser();
    my $workspace   = create_test_workspace(user => $system_user);
    my $user        = create_test_user();
    my $group_one   = create_test_group();
    my $group_two   = create_test_group();

    # User has multiple Roles in the WS via Group memberships
    $group_one->add_user(user => $user);
    $workspace->add_group(group => $group_one);

    $group_two->add_user(user => $user);
    $workspace->add_group(group => $group_two);

    # Get the count of Users in the Workspace
    my $count = Socialtext::Workspace::Roles->CountUsersByWorkspaceId(
        workspace_id => $workspace->workspace_id,
    );
    is $count, 1, 'WS has correct number of Users';
}

###############################################################################
# TEST: User has a specific Role in the WS.
user_has_role: {
    my $system_user = Socialtext::User->SystemUser();
    my $workspace   = create_test_workspace(user => $system_user);
    my $role_admin  = Socialtext::Role->WorkspaceAdmin();
    my $role_member = Socialtext::Role->Member();
    my $role_guest  = Socialtext::Role->Guest();
    my $rc;

    # User has explicit UWR
    user_has_role_explicit_uwr: {
        my $user = create_test_user();
        $workspace->add_user(user => $user, role => $role_admin);

        $rc = $workspace->user_has_role(user => $user, role => $role_admin);
        ok $rc, 'User with explicit UWR has specific Role in WS';

        $rc = $workspace->user_has_role(user => $user, role => $role_guest);
        ok !$rc, 'User does not have this Role in WS';
    }

    # User has UWR+GWR
    user_has_role_uwr_and_gwr: {
        my $user = create_test_user();
        $workspace->add_user(user => $user, role => $role_admin);

        my $group = create_test_group();
        $group->add_user(user => $user);
        $workspace->add_group(group => $group, role => $role_member);

        $rc = $workspace->user_has_role(user => $user, role => $role_admin);
        ok $rc, 'User has UWR Role in WS';
        
        $rc = $workspace->user_has_role(user => $user, role => $role_member);
        ok $rc, 'User has GWR Role in WS';

        $rc = $workspace->user_has_role(user => $user, role => $role_guest);
        ok !$rc, 'User does not have this Role in WS';
    }

    # User has multiple GWRs
    user_has_role_multiple_gwrs: {
        my $user      = create_test_user();
        my $group_one = create_test_group();
        my $group_two = create_test_group();

        $group_one->add_user(user => $user);
        $workspace->add_group(group => $group_one, role => $role_admin);

        $group_two->add_user(user => $user);
        $workspace->add_group(group => $group_two, role => $role_member);

        $rc = $workspace->user_has_role(user => $user, role => $role_admin);
        ok $rc, 'User has GWR Role in WS';
        
        $rc = $workspace->user_has_role(user => $user, role => $role_member);
        ok $rc, 'User has alternate GWR Role in WS';

        $rc = $workspace->user_has_role(user => $user, role => $role_guest);
        ok !$rc, 'User does not have this Role in WS';
    }
}

###############################################################################
# TEST: Get the list of Roles for a User in the Workspace.
get_roles_for_user_in_workspace: {
    my $system_user = Socialtext::User->SystemUser();
    my $workspace   = create_test_workspace(user => $system_user);
    my $role_admin  = Socialtext::Role->WorkspaceAdmin();
    my $role_member = Socialtext::Role->Member();
    my $role_guest  = Socialtext::Role->Guest();

    get_roles_for_user_explicit_uwr: {
        my $user = create_test_user();
        $workspace->add_user(user => $user, role => $role_admin);

        my $role = Socialtext::Workspace::Roles->RolesForUserInWorkspace(
            user      => $user,
            workspace => $workspace,
        );
        isa_ok $role, 'Socialtext::Role', 'Users Role in WS';
        is $role->role_id(), $role_admin->role_id(),
            '... is the assigned Role';
    }

    get_roles_for_user_uwr_and_gwr: {
        my $user = create_test_user();
        $workspace->add_user(user => $user, role => $role_admin);

        my $group = create_test_group();
        $group->add_user(user => $user);
        $workspace->add_group(group => $group, role => $role_member);

        # SCALAR: highest effective Role
        my $role = Socialtext::Workspace::Roles->RolesForUserInWorkspace(
            user      => $user,
            workspace => $workspace,
        );
        is $role->role_id, $role_admin->role_id,
            'Users highest effective Role in the WS';

        # LIST: all Roles, ordered from highest->lowest
        my @roles = Socialtext::Workspace::Roles->RolesForUserInWorkspace(
            user      => $user,
            workspace => $workspace,
        );
        is scalar @roles, 2, 'User has multiple Roles in the WS';
        is $roles[0]->role_id, $role_admin->role_id,
            '... first Role has higher effectiveness';
        is $roles[1]->role_id, $role_member->role_id,
            '... second Role has lower effectiveness';
    }

    get_roles_for_user_multiple_gwrs: {
        my $user      = create_test_user();
        my $group_one = create_test_group();
        my $group_two = create_test_group();

        $group_one->add_user(user => $user);
        $workspace->add_group(group => $group_one, role => $role_member);

        $group_two->add_user(user => $user);
        $workspace->add_group(group => $group_two, role => $role_guest);

        # SCALAR: highest effective Role
        my $role = Socialtext::Workspace::Roles->RolesForUserInWorkspace(
            user      => $user,
            workspace => $workspace,
        );
        is $role->role_id, $role_member->role_id,
            'Users highest effective Role in the WS';

        # LIST: all Roles, ordered from highest->lowest
        my @roles = Socialtext::Workspace::Roles->RolesForUserInWorkspace(
            user      => $user,
            workspace => $workspace,
        );
        is scalar @roles, 2, 'User has multiple Roles in the WS';
        is $roles[0]->role_id, $role_member->role_id,
            '... first Role has higher effectiveness';
        is $roles[1]->role_id, $role_guest->role_id,
            '... second Role has lower effectiveness';
    }
}
