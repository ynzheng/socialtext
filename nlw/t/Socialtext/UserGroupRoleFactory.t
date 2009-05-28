#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 16;
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
    my $ugr   = Socialtext::UserGroupRoleFactory->Create( {
        user_id  => $user->user_id,
        group_id => $group->group_id,
        role_id  => $role->role_id,
    } );
    isa_ok $ugr, 'Socialtext::UserGroupRole', 'created UGR';
    is $ugr->user_id,  $user->user_id,   '... with provided user_id';
    is $ugr->group_id, $group->group_id, '... with provided group_id';
    is $ugr->role_id,  $role->role_id,   '... with provided role_id';

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
