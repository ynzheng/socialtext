#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 21;
use Socialtext::UserGroupRoleFactory;

###############################################################################
# Fixtures: db
# - need a DB, but don't care what's in it.
fixtures(qw( db ));

use_ok 'Socialtext::Group';

################################################################################
# NOTE: this behaviour is more extensively tested in
# t/Socialtext/UserGroupRoleFactory.t
################################################################################

################################################################################
# TEST: Group has no users; it's a lonely, lonely group.
group_with_no_users: {
    my $group = create_test_group();
    my $users = $group->users();

    isa_ok $users, 'Socialtext::MultiCursor', 'got a list of users';
    is $users->count(), 0, '... with the correct count';
}

###############################################################################
# TEST: add User to Group
add_user_to_group: {
    my $group = create_test_group();
    my $user  = create_test_user();

    # group should be empty
    my $count = $group->users->count();
    is $count, 0, 'Group is empty';

    # add the User to the Group
    $group->assign_role_to_user( user => $user );

    # group should now contain a User
    my $members = $group->users();
    is $members->count, 1, '... Group now contains a User';
    is $members->next->user_id, $user->user_id, '... ... our test User';

    # User should have been given the Default role
    my $ugr = Socialtext::UserGroupRoleFactory->GetUserGroupRole(
        user_id  => $user->user_id,
        group_id => $group->group_id,
    );
    isa_ok $ugr, 'Socialtext::UserGroupRole', '... Users Role';
    is $ugr->role_id, Socialtext::UserGroupRoleFactory->DefaultRoleId(),
        '... ... the Default Role';
}

################################################################################
# TEST: add User to Group with explicit Role
add_user_to_group_with_role: {
    my $group = create_test_group();
    my $user  = create_test_user();

    # Get a Role that *isn't* the Default Role
    my $role  = Socialtext::Role->new( name => 'guest' );
    isnt $role->role_id, Socialtext::UserGroupRoleFactory->DefaultRoleId(),
        'Role is _not_ the Default UGR Role';

    # add the User to the Group
    $group->assign_role_to_user( user => $user, role => $role );

    # User should have been given the correct Role
    my $ugr = Socialtext::UserGroupRoleFactory->GetUserGroupRole(
        user_id  => $user->user_id,
        group_id => $group->group_id,
    );
    isa_ok $ugr, 'Socialtext::UserGroupRole', '... Users Role';
    is $ugr->role_id, $role->role_id, '... ... the assigned Role';
}

################################################################################
# TEST: change Role for User already in Group
change_role_for_user: {
    my $group = create_test_group();
    my $user  = create_test_user();

    # Get a Role that *isn't* the Default Role
    my $role  = Socialtext::Role->new( name => 'guest' );
    isnt $role->role_id, Socialtext::UserGroupRoleFactory->DefaultRoleId(),
        'Role is _not_ the Default UGR Role';

    # add User to the Group, with the Default Role
    $group->assign_role_to_user( user => $user );

    # change the User's Role
    $group->assign_role_to_user( user => $user, role => $role );

    # User should have been re-assigned the new Role
    my $ugr = Socialtext::UserGroupRoleFactory->GetUserGroupRole(
        user_id  => $user->user_id,
        group_id => $group->group_id,
    );
    isa_ok $ugr, 'Socialtext::UserGroupRole', '... Users Role';
    is $ugr->role_id, $role->role_id, '... ... the re-assigned Role';
}

################################################################################
# TEST: does this User have a Role in this Group?
does_user_have_role: {
    my $group = create_test_group();
    my $user  = create_test_user();

    # User doesn't (yet) have a Role in the Group
    ok !$group->has_user($user), 'User has no Role in Group';

    # add User to the Group
    $group->assign_role_to_user( user => $user );

    # User should now have a Role in the Group
    ok $group->has_user($user), '... User now has a Role';
}

################################################################################
# TEST: what is the Role for this User in the Group?
what_is_users_role: {
    my $group = create_test_group();
    my $user  = create_test_user();

    # Get a Role that *isn't* the Default Role
    my $role  = Socialtext::Role->new( name => 'guest' );
    isnt $role->role_id, Socialtext::UserGroupRoleFactory->DefaultRoleId(),
        'Role is _not_ the Default UGR Role';

    # User doesn't (yet) have a Role in the Group
    my $queried = $group->role_for_user( user => $user );
    ok !$queried, 'User has no Role in Group';

    # add the User to the Group
    $group->assign_role_to_user( user => $user, role => $role );

    # User should now have that Role in the Group
    $queried = $group->role_for_user( user => $user );
    is $queried->role_id, $role->role_id, '... User now has assigned Role';
}

################################################################################
# TEST: remove User from Group
remove_user_from_group: {
    my $group = create_test_group();
    my $user  = create_test_user();

    # add the User to the Group
    $group->assign_role_to_user( user => $user );

    # make sure User got added successfully
    ok $group->has_user($user), 'User has Role in Group';

    # remove the User and make sure they no longer have a Role
    $group->remove_user( user => $user );
    ok !$group->has_user($user), '... User has been removed from Group';
}
