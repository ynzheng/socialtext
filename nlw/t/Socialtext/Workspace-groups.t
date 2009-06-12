#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 6;
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
