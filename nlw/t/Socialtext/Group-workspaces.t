#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 5;
use Socialtext::GroupWorkspaceRoleFactory;

###############################################################################
# Fixtures: db
# - need a DB, but don't care what's in it.
fixtures(qw( db ));

use_ok 'Socialtext::Group';

################################################################################
# NOTE: this behaviour is more extensively tested in
# t/Socialtext/GroupWorkspaceRoleFactory.t
################################################################################

################################################################################
# TEST: Group is in no Workspaces; has no GWRs
group_with_no_workspaces: {
    my $group      = create_test_group();
    my $workspaces = $group->workspaces();

    isa_ok $workspaces, 'Socialtext::MultiCursor', 'got a list of workspaces';
    is $workspaces->count(), 0, '... with the correct count';
}

################################################################################
# TEST: Group has Role in some Workspaces
group_has_workspaces: {
    my $user   = create_test_user();
    my $ws_one = create_test_workspace(user => $user);
    my $ws_two = create_test_workspace(user => $user);
    my $group  = create_test_group();

    # Create GWRs, giving the Group a default Role
    Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group->group_id,
        workspace_id => $ws_one->workspace_id,
    } );

    Socialtext::GroupWorkspaceRoleFactory->Create( {
        group_id     => $group->group_id,
        workspace_id => $ws_two->workspace_id,
    } );

    my $workspaces = $group->workspaces();

    isa_ok $workspaces, 'Socialtext::MultiCursor', 'got a list of workspaces';
    is $workspaces->count(), 2, '... with the correct count';
}
