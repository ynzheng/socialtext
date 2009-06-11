#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext tests => 15;
use Test::Exception;
use Test::Socialtext::Account;
use Test::Socialtext::User;
use Socialtext::UserGroupRoleFactory;
use Socialtext::Role;

use_ok 'Socialtext::Pluggable::Plugin::Groups';

###############################################################################
# Fixtures: db
# - we need a DB, but don't care what's in it.
fixtures(qw/db/);

################################################################################
# TEST: backup
backup: {
    my $data_ref = {};
    my $def_user = Socialtext::User->SystemUser;
    my $def_role = Socialtext::UserGroupRoleFactory->DefaultRole();

    # create dummy data.
    my $account   = create_test_account();
    my $group_one = create_test_group(account => $account);
    my $user_one  = create_test_user();
    add_user_to_group($user_one, $group_one);

    # this group will _not_ be in the backup; it's not in the account.
    my $group_two    = create_test_group();
    add_user_to_group( $user_one, $group_two);

    # make backup data
    my $plugin = Socialtext::Pluggable::Plugin::Groups->new();
    $plugin->export_groups_for_account($account, $data_ref);

    my $expected = [
        {
            'users' => [
                {
                    'role_name' => $def_role->name,
                    'username'  => $user_one->username,
                } 
            ],
            'created_by_username' => $def_user->username,
            'driver_group_name'   => $group_one->driver_group_name,
        } 
    ];

    is_deeply $data_ref->{groups}, $expected, 'correct export data structure';
}

################################################################################
# TEST: restore
basic_restore: {
    my $data_ref = {};
    my ($test_username, $test_creator_name, $test_group_name, $test_role_name);

    do_backup: {
        my $account = create_test_account();
        my $user    = create_test_user();
        my $group   = create_test_group(account => $account);
        add_user_to_group($user, $group);

        # hold onto the User's name, so we can check for it later after import
        $test_username     = $user->username();
        $test_creator_name = $group->creator->username();
        $test_group_name   = $group->driver_group_name();
        $test_role_name = Socialtext::UserGroupRoleFactory->GetUserGroupRole(
            user_id  => $user->user_id(),
            group_id => $group->group_id(),
        )->role->name();

        # make backup data
        my $plugin = Socialtext::Pluggable::Plugin::Groups->new();
        $plugin->export_groups_for_account($account, $data_ref);

        ### CLEANUP: nuke stuff in DB before we import
        ### - we can't nuke the User; the Account import is responsible for
        ###   re-creating the User, not the Groups import
        $group->delete();
        Test::Socialtext::Account->delete_recklessly( $account );

        # SANITY CHECK: User/Group/Account should *NOT* be in the DB any more
        $group = Socialtext::Group->GetGroup(group_id => $group->group_id);
        $account
            = Socialtext::Account->new(account_id => $account->account_id);

        ok !$group,   '... group has been deleted';
        ok !$account, '... account has been deleted';
    }

    # import the data that we just exported
    my $plugin  = Socialtext::Pluggable::Plugin::Groups->new();
    my $account = create_test_account();
    $plugin->import_groups_for_account($account, $data_ref);

    my $groups = $account->groups;
    is $groups->count, 1, 'got a group';

    # Test group
    my $group = $groups->next;
    is $group->account_id, $account->account_id, '... with correct account_id';
    is $group->driver_group_name, $test_group_name,
        '... with correct driver_group_name';

    # make sure that the creator exists
    my $creator = $group->creator;
    isa_ok $creator, 'Socialtext::User', '... creator';
    is $creator->username, $test_creator_name, '... ... correct creating User';
    
    # Test users
    my $users = $group->users;
    is $users->count, 1, 'got a user';
    
    my $user = $users->next;
    isa_ok $user, 'Socialtext::User', '... member User';
    is $user->username, $test_username, '... ... is test User';

    # User has the correct Role in the Group
    my $ugr = Socialtext::UserGroupRoleFactory->GetUserGroupRole(
        user_id  => $user->user_id,
        group_id => $group->group_id,
    );
    is $ugr->role->name(), $test_role_name, '... correct Role in Group';
}

################################################################################
# TEST: restore, pre-groups
restore_no_groups: {
    my $data_ref = {};
    my $account  = create_test_account();
    my $plugin   = Socialtext::Pluggable::Plugin::Groups->new();

    lives_ok { $plugin->import_groups_for_account( $account, $data_ref ) }
        'import with no groups data lives';

    is $account->groups->count, 0, '... and no groups are imported';
}




###############################################################################
# Helper method, to add a User to a Group.
sub add_user_to_group {
    my $user  = shift;
    my $group = shift;

    Socialtext::UserGroupRoleFactory->Create({
        user_id  => $user->user_id, 
        group_id => $group->group_id,
    });
}
