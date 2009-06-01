#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext qw/no_plan/;
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
}

################################################################################
# TEST: restore
################################################################################
# TEST: restore, group exists already
################################################################################
# TEST: restore, user exists already
################################################################################
# TEST: restore, pre-groups

exit;

sub add_user_to_group {
    my $user  = shift;
    my $group = shift;

    Socialtext::UserGroupRoleFactory->Create({
        user_id  => $user->user_id, 
        group_id => $group->group_id,
    });
}
