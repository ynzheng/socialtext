package Socialtext::Pluggable::Plugin::Groups;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Pluggable::Plugin';
use Socialtext::Group;
use Socialtext::l10n qw/loc/;
use Socialtext::Role;
use Socialtext::User;
use Socialtext::UserGroupRoleFactory;

sub register {
    my $class = shift;
    $class->add_hook(
        'nlw.export_account' => 'export_groups_for_account');
    $class->add_hook(
        'nlw.finish_import_account' => 'import_groups_for_account');
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

sub import_groups_for_account {
    my $self   = shift;
    my $acct   = shift;
    my $data   = shift;
    my $groups = $data->{groups} || [];

    return unless @$groups;

    print loc("Importing all groups for account '[_1]'...", $acct->name ), "\n";

    for my $group_info ( @$groups ) {
        my $creator = Socialtext::User->new(
            username => $group_info->{created_by_username} );

        # TODO: Do something if the creator doesn't exist?
        $creator ||= Socialtext::User->SystemUser;

        my $group = Socialtext::Group->Create({
            driver_group_name  => $group_info->{driver_group_name},
            created_by_user_id => $creator->user_id,
            account_id         => $acct->account_id,
        });

        $self->_set_ugrs_on_import( $group, $group_info->{users} );
    }
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

sub _set_ugrs_on_import {
    my $self  = shift;
    my $group = shift;
    my $data  = shift;

    for my $ugr_data ( @$data ) {
        my $role = Socialtext::Role->new( name => $ugr_data->{role_name} );
        die loc("No role named [_1] found.\n", $ugr_data->{role_name})
            unless $role;

        my $user = Socialtext::User->new( username => $ugr_data->{username} );
        next unless $user;

        Socialtext::UserGroupRoleFactory->Create( {
            user_id  => $user->user_id,
            group_id => $group->group_id,
            role_id  => $role->role_id,
        } );
    }
}

1;
