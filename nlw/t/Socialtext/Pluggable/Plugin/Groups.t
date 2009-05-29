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

################################################################################
# TEST: backup
backup: {
    my $def_user = Socialtext::User->SystemUser;
    my $def_role = Socialtext::Role->new(
        role_id => Socialtext::UserGroupRoleFactory->DefaultRoleId() );

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
    my $ref = $plugin->export_groups_for_account($account);

    # tests
    is @$ref, 1, 'backed up one group.';
    is $ref->[0]{driver_group_name}, $group_one->driver_group_name,
        '... with right name';
    is $ref->[0]{created_by_username}, $def_user->username, 
        '... with correct creator';
    is @{ $ref->[0]{users} }, 1, '... backed up one user';
    is $ref->[0]{users}[0]{username}, $user_one->username,
        '... ... user has correct username';
    is $ref->[0]{users}[0]{role_name}, $def_role->name,
        '... ... user has correct role name';
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
