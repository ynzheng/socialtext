#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 12;

###############################################################################
# Fixtures: db
# - need a DB, don't care what's in it
fixtures(qw( db ));

use_ok 'Socialtext::UserGroupRole';

###############################################################################
# TEST: instantiation
instantiation: {
    my $ugr = Socialtext::UserGroupRole->new( {
        user_id  => 1,
        group_id => 2,
        role_id  => 3,
        } );
    isa_ok $ugr, 'Socialtext::UserGroupRole';
    is $ugr->user_id,  1, '... with the provided user_id';
    is $ugr->group_id, 2, '... with the provided group_id';
    is $ugr->role_id,  3, '... with the provided role_id';
}

###############################################################################
# TEST: instantiation with actual User/Group/Role
instantiation_with_real_data: {
    my $user  = create_test_user();
    my $group = create_test_group();
    my $role  = Socialtext::Role->new( name => 'member' );
    my $ugr   = Socialtext::UserGroupRole->new( {
        user_id  => $user->user_id,
        group_id => $group->group_id,
        role_id  => $role->role_id,
        } );
    isa_ok $ugr, 'Socialtext::UserGroupRole';

    is $ugr->user_id,  $user->user_id,   '... with the provided user_id';
    is $ugr->group_id, $group->group_id, '... with the provided group_id';
    is $ugr->role_id,  $role->role_id,   '... with the provided role_id';

    is $ugr->user->user_id, $user->user_id,
        '... with the right inflated User object';
    is $ugr->group->group_id, $group->group_id,
        '... with the right inflated Group object';
    is $ugr->role->role_id, $role->role_id,
        '... with the right inflated Role object';
}
