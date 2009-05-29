#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext qw/no_plan/;
use Socialtext::UserGroupRoleFactory;

# Need a DB, but don't care what's in it.
fixtures(qw/db/);

use_ok 'Socialtext::User';

################################################################################
# NOTE: this behaviour is more extensively tested in
# t/Socialtext/UserGroupRoleFactory.t
################################################################################

################################################################################
# TEST: User is in no groups
user_has_no_groups: {
    my $me = create_test_user();
    my $groups = $me->groups;

    isa_ok $groups, 'Socialtext::MultiCursor', 'got a list of groups';
    is $groups->count(), 0, '... with the correct count';
}

################################################################################
# TEST: User is in groups
user_has_groups: {
    my $me        = create_test_user();
    my $group_one = create_test_group();
    my $group_two = create_test_group();

    # Create UGRs, giving the user a default role.
    Socialtext::UserGroupRoleFactory->Create( {
        user_id  => $me->user_id,
        group_id => $group_one->group_id,
    } );

    Socialtext::UserGroupRoleFactory->Create( {
        user_id  => $me->user_id,
        group_id => $group_two->group_id,
    } );

    my $groups = $me->groups();

    isa_ok $groups, 'Socialtext::MultiCursor', 'got a list of groups';
    is $groups->count(), 2, '... with the correct count';
    isa_ok $groups->next(), 'Socialtext::Group', '...';
}
