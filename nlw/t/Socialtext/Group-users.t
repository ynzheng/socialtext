#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 5;
use Socialtext::UserGroupRoleFactory;

################################################################################
# Fixtures: db
# - need a DB, but don't care what's in it.
fixtures(qw( db ));

use_ok 'Socialtext::Group';

################################################################################
# NOTE: this behaviour is more extensively tested in
# t/Socialtext/UserGroupRoleFactory.t
################################################################################

################################################################################
# TEST: Group has no Users; it's a lonely, lonely group.
group_with_no_users: {
    my $group = create_test_group();
    my $users = $group->users();

    isa_ok $users, 'Socialtext::MultiCursor', 'got a list of users';
    is $users->count(), 0, '... with the correct count';
}

################################################################################
# TEST: Group has some Users
group_has_users: {
    my $group    = create_test_group();
    my $user_one = create_test_user();
    my $user_two = create_test_user();

    # Create UGRs, giving the user a default role.
    Socialtext::UserGroupRoleFactory->Create( {
        user_id  => $user_one->user_id,
        group_id => $group->group_id,
    } );

    Socialtext::UserGroupRoleFactory->Create( {
        user_id  => $user_two->user_id,
        group_id => $group->group_id,
    } );

    my $users = $group->users();

    isa_ok $users, 'Socialtext::MultiCursor', 'got a list of users';
    is $users->count(), 2, '... with the correct count';
}
