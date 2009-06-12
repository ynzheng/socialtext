#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 14;
use Test::Exception;

###############################################################################
# Fixtures: db
# - need a DB, don't care what's in it
fixtures(qw( db ));

use_ok 'Socialtext::GroupWorkspaceRole';

###############################################################################
# TEST: instantiation
instantiation: {
    my $gwr = Socialtext::GroupWorkspaceRole->new( {
        group_id     => 1,
        workspace_id => 2,
        role_id      => 3,
        } );
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole';
    is $gwr->group_id,     1, '... with the provided group_id';
    is $gwr->workspace_id, 2, '... with the provided workspace_id';
    is $gwr->role_id,      3, '... with the provided role_id';
}

###############################################################################
# TEST: instantiation with additional attributes
instantiation_with_extra_attributes: {
    my $gwr;
    lives_ok sub {
        $gwr = Socialtext::GroupWorkspaceRole->new( {
            group_id     => 1,
            workspace_id => 2,
            role_id      => 3,
            bogus        => 'attribute',
        } );
    }, 'created GWR when additional attributes provided';
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole', '... created GWR';
}

###############################################################################
# TEST: instantiation with actual Group/Workspace/Role
instantiation_with_real_data: {
    my $user  = Socialtext::User->SystemUser();
    my $group = create_test_group();
    my $ws    = create_test_workspace( user => $user );
    my $role  = Socialtext::Role->new( name => 'member' );
    my $gwr   = Socialtext::GroupWorkspaceRole->new( {
        group_id     => $group->group_id,
        workspace_id => $ws->workspace_id,
        role_id      => $role->role_id,
        } );
    isa_ok $gwr, 'Socialtext::GroupWorkspaceRole';

    is $gwr->group_id, $group->group_id, '... with the provided group_id';
    is $gwr->workspace_id, $ws->workspace_id,
        '... with the provided workspace_id';
    is $gwr->role_id,  $role->role_id,   '... with the provided role_id';

    is $gwr->group->group_id, $group->group_id,
        '... with the right inflated Group object';
    is $gwr->workspace->workspace_id, $ws->workspace_id,
        '... with the right inflated Workspace object';
    is $gwr->role->role_id, $role->role_id,
        '... with the right inflated Role object';
}
