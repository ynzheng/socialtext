#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext qw/no_plan/;
use Test::Exception;
use Test::Socialtext::Account;
use Test::Socialtext::Group;
use Test::Socialtext::User;
use Socialtext::UserGroupRoleFactory;
use Socialtext::Role;

use_ok 'Socialtext::Pluggable::Plugin::Groups';

# We need a DB, but don't care what's in it.
fixtures(qw/db/);

my $data_ref = {};

################################################################################
# TEST: backup
backup: {
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

    # cleanup
    Test::Socialtext::Group->delete_recklessly( $group_one );
    Test::Socialtext::Group->delete_recklessly( $group_two );
    Test::Socialtext::Account->delete_recklessly( $account );
}

################################################################################
# TEST: restore
basic_restore: {
    my $data    = $data_ref->{groups};
    my $account = create_test_account();
    my $plugin  = Socialtext::Pluggable::Plugin::Groups->new();
    my $creator = Socialtext::User->new(
        username => $data->[0]{created_by_username} );

    # import the data that we just exported
    $plugin->import_groups_for_account($account, $data_ref);

    my $groups = $account->groups;
    is $groups->count, 1, 'got a group';

    # Test group
    my $group = $groups->next;
    is $group->account_id, $account->account_id, '... with correct account_id';
    is $group->driver_group_name, $data->[0]{driver_group_name},
        '... with correct driver_group_name';

    # make sure that the creator exists
    isa_ok $creator, 'Socialtext::User', '... creator';
    is $group->creator->user_id, $creator->user_id, '... ... with correct id';
    
    # Test users
    my $users = $group->users;
    is $users->count, 1, 'got a user';
    
    my $user = $users->next;
    is $user->username, $data->[0]{users}[0]{username}, '... with correct id';

    # TODO: test for correct role.
    
    # cleanup.
    Test::Socialtext::Group->delete_recklessly( $group );
    Test::Socialtext::Account->delete_recklessly( $account );
}

################################################################################
# TEST: restore, group exists already

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

exit;

sub add_user_to_group {
    my $user  = shift;
    my $group = shift;

    Socialtext::UserGroupRoleFactory->Create({
        user_id  => $user->user_id, 
        group_id => $group->group_id,
    });
}
