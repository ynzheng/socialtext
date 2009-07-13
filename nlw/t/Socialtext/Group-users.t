#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 17;
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
    # - we do this via UGR as we haven't tested the other helper methods yet
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
    isa_ok $users->next(), 'Socialtext::User', '... queried User';
}

################################################################################
# TEST: Add User to Group with default Role
add_user_to_group_with_default_role: {
    my $group = create_test_group();
    my $user  = create_test_user();

    # Group should be empty (have no Users)
    is $group->users->count(), 0, 'Group has no Users in it (yet)';

    # Add the User to the Group
    $group->add_user(user => $user);

    # Make sure the User got added properly
    is $group->users->count(), 1, '... added User to Group';

    # Make sure User was given the default Role
    my $default_role = Socialtext::UserGroupRoleFactory->DefaultRole();
    my $users_role   = $group->role_for_user($user);
    is $users_role->role_id, $default_role->role_id,
        '... with Default UGR Role';
}

###############################################################################
# TEST: Add User to Group with explicit Role
add_user_to_group_with_role: {
    my $group = create_test_group();
    my $user  = create_test_user();
    my $role  = Socialtext::Role->Guest();

    # Group should be empty (have no Users)
    is $group->users->count(), 0, 'Group has no Users in it (yet)';

    # Add the User to the Group
    $group->add_user(user => $user, role => $role);

    # Make sure the User got added properly
    is $group->users->count(), 1, '... added User to Group';

    # Make sure User has correct Role
    my $users_role   = $group->role_for_user($user);
    is $users_role->role_id, $role->role_id, '... with provided Role';
}

###############################################################################
# TEST: Update User's Role in Group
update_users_role_in_group: {
    my $group = create_test_group();
    my $user  = create_test_user();
    my $role  = Socialtext::Role->Guest();

    # Add the User to the Group, with Default Role
    $group->add_user(user => $user);

    # Make sure the User was given the Default Role
    my $default_role = Socialtext::UserGroupRoleFactory->DefaultRole();
    my $users_role   = $group->role_for_user($user);
    is $users_role->role_id, $default_role->role_id,
        '... with Default UGR Role';

    # Update the User's Role
    $group->add_user(user => $user, role => $role);

    # Make sure User had their Role updated
    $users_role = $group->role_for_user($user);
    is $users_role->role_id, $role->role_id, '... with updated Role';
}

###############################################################################
# TEST: Get the Role for a User
get_role_for_user: {
    my $group = create_test_group();
    my $user  = create_test_user();

    # Add the User to the Group
    $group->add_user(user => $user);

    # Get the Role for the User
    my $role = $group->role_for_user($user);
    isa_ok $role, 'Socialtext::Role', 'queried Role';
}

###############################################################################
# TEST: Does this User have a Role in the Group
does_group_have_user: {
    my $group = create_test_group();
    my $user  = create_test_user();

    # Group should not (yet) have this User
    ok !$group->has_user($user), 'User does not yet have Role in Group';

    # Add the User to the Group
    $group->add_user(user => $user);

    # Now the User is in the Group
    ok $group->has_user($user), '... but has now been added';
}
