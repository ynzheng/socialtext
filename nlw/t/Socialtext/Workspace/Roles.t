#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 8;

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
