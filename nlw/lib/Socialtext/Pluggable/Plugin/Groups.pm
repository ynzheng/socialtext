package Socialtext::Pluggable::Plugin::Groups;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Pluggable::Plugin';
use Socialtext::Group;
use Socialtext::l10n qw/loc/;
use Socialtext::UserGroupRoleFactory;

sub register {
    my $class = shift;
    $class->add_hook(
        'nlw.export_account' => 'export_groups_for_account');
}

sub export_groups_for_account {
    my $self     = shift;
    my $acct     = shift;
    my $data_ref = shift;
    my @groups   = ();

    print loc("Exporting all groups for account '[_1]'...", $acct->name ), "\n";

    my $groups = 
        Socialtext::Group->ByAccountId(account_id => $acct->account_id);

    while ( my $group = $groups->next() ) {
        my $group_data = {
           driver_group_name => $group->driver_group_name,
           created_by_username =>  $group->creator->username,
        };
        $group_data->{users} = $self->_get_ugrs_for_export( $group );
        push @groups, $group_data;
    }

    $data_ref->{groups} = \@groups;
}

sub _get_ugrs_for_export {
    my $self  = shift;
    my $group = shift;
    my @users = ();

    my $ugrs = Socialtext::UserGroupRoleFactory->ByGroupId( $group->group_id );

    while ( my $ugr = $ugrs->next() ) {
        my $user = {
            username => $ugr->user->username,
            role_name => $ugr->role->name,
        };
        push @users, $user;
    }

    return \@users;
}

1;
