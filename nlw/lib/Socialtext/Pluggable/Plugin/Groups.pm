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
        # Find the User who created the Group, falling back on the SystemUser
        # if they can't be found.  This matches the behaviour of Workspace
        # imports (where we assign the WS to the SystemUser).
        my $creator = Socialtext::User->new(
            username => $group_info->{created_by_username} );
        $creator ||= Socialtext::User->SystemUser;

        # See if the Group already exists.  If it doesn't, create a new Group.
        my $group = Socialtext::Group->GetGroup( {
            driver_group_name  => $group_info->{driver_group_name},
            created_by_user_id => $creator->user_id,
            primary_account_id => $acct->account_id,
        } );
        unless ($group) {
            $group = Socialtext::Group->Create( {
                driver_group_name  => $group_info->{driver_group_name},
                created_by_user_id => $creator->user_id,
                primary_account_id => $acct->account_id,
            } );
        }

        # Add all of the Users from the export into the Group
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
            username  => $ugr->user->username,
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
        my $role = Socialtext::Role->new(name => $ugr_data->{role_name})
            || Socialtext::UserGroupRoleFactory->DefaultRole();

        # Get the User that we're creating the UGR for
        my $user = Socialtext::User->new( username => $ugr_data->{username} );
        next unless $user;

        # Don't over-write existing UGRs; if the User already has a Role in
        # the Group then preserve their existing Role.
        next if ($group->has_user($user));

        # Create a new UGR for the User in this Group.
        $group->add_user( user => $user, role => $role );
    }
}

1;

=head1 NAME

Socialtext::Pluggable::Plugin::Groups

=head1 DESCRIPTION

C<Socialtext::Pluggable::Plugin::Groups> provides a means for hooking the
Groups infrastructure into the Socialtext Account import/export facilities.

=head1 METHODS

=over

=item B<Socialtext::Pluggable::Plugin::Groups-E<gt>register()>

Registers the plugin with the system.

=item B<$plugin-E<gt>export_groups_for_account($account, $data_ref)>

Exports information on all of the Groups that live within the provided
C<$account>, by adding group information to the provided C<$data_ref>
hash-ref.

=item B<$plugin-E<gt>import_groups_for_account($account, $data_ref)>

Imports Group information from the provided C<$data_ref> hash-ref, adding the
Groups and their membership lists to the given C<$account>.

If the Group I<already exists> within the Account, any Users/Roles that are
present in the export but that are I<not> present in the Group are added
automatically to the Group; missing Users get added to the Group, but existing
Users and their Roles are untouched.

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
