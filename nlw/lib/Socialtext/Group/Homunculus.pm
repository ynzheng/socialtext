package Socialtext::Group::Homunculus;
# @COPYRIGHT@

use Moose;
use Socialtext::MooseX::SQL;
use Socialtext::MooseX::Types::Pg;
use Socialtext::Account;
use Socialtext::User;
use Socialtext::Group;
use namespace::clean -except => 'meta';

has_column 'group_id' => (
    is => 'rw', isa => 'Int',
    writer => '_group_id',
    primary_key => 1,
);

has_column 'driver_key' => (
    is => 'rw', isa => 'Str',
    writer => '_driver_key',
    trigger => \&_set_driver_key,
    required => 1,
);

has 'driver_name' => (
    is => 'ro', isa => 'Str',
    lazy_build => 1,
);

has 'driver_id' => (
    is => 'ro', isa => 'Maybe[Str]',
    lazy_build => 1,
);

has_column 'driver_unique_id' => (
    is => 'rw', isa => 'Str',
    writer => '_driver_unique_id',
    required => 1,
);

has_column 'driver_group_name' => (
    is => 'rw', isa => 'Str',
    writer => '_driver_group_name',
    required => 1,
);

has_column 'account_id' => (
    is => 'rw', isa => 'Int',
    writer => '_account_id',
    trigger => \&_set_account_id,
    required => 1,
);

has 'account' => (
    is => 'ro', isa => 'Socialtext::Account',
    lazy_build => 1,
);

has_column 'creation_datetime' => (
    is => 'rw', isa => 'Pg.DateTime',
    writer => '_creation_datetime',
    required => 1,
    coerce => 1,
);

has_column 'created_by_user_id' => (
    is => 'rw', isa => 'Int',
    writer => '_created_by_user_id',
    trigger => \&_set_created_by_user_id,
    required => 1,
);

has 'creator' => (
    is => 'ro', isa => 'Socialtext::User',
    lazy_build => 1,
);

has_column 'cached_at' => (
    is => 'rw', isa => 'Pg.DateTime',
    writer => '_cached_at',
    coerce => 1,
);

has 'is_system_managed' => (
    is => 'ro', isa => 'Bool',
    lazy_build => 1,
);

has 'factory' => (
    is => 'ro', isa => 'Socialtext::Group::Factory',
    lazy_build => 1,
    handles => [qw( can_update_store )],
);

sub _set_driver_key {
    my $self = shift;
    $self->clear_driver_name();
    $self->clear_driver_id();
    $self->clear_factory();
}

sub _build_driver_name {
    my $self = shift;
    my ($name, $id) = split /:/, $self->driver_key();
    return $name;
}

sub _build_driver_id {
    my $self = shift;
    my ($name, $id) = split /:/, $self->driver_key();
    return $id;
}

sub _set_account_id {
    my $self = shift;
    $self->clear_account();
}

sub _build_account {
    my $self    = shift;
    my $acct_id = $self->account_id();
    my $acct    = Socialtext::Account->new(account_id => $acct_id);
    unless ($acct) {
        die "account id=$acct_id no longer exists";
    }
    return $acct;
}

sub _set_created_by_user_id {
    my $self = shift;
    $self->clear_creator();
    $self->clear_is_system_managed();
}

sub _build_creator {
    my $self    = shift;
    my $user_id = $self->created_by_user_id();
    my $user    = Socialtext::User->new(user_id => $user_id);
    unless ($user) {
        die "user id=$user_id no longer exists";
    }
    return $user;
}

# We're system-managed if we were created by the SystemUser
sub _build_is_system_managed {
    my $self = shift;
    my $creator_id = $self->created_by_user_id();
    return $creator_id == Socialtext::User->SystemUser->user_id ? 1 : 0;
}

# Instantiate our Factory
sub _build_factory {
    my $self = shift;
    return Socialtext::Group->Factory(driver_key => $self->driver_key);
}

# expire the homunculus, so our Factory knows that it should refresh us next
# time we're instantiated
sub expire {
    my $self = shift;
    $self->factory->ExpireGroupRecord(group_id => $self->group_id);
}

sub update_store {
    my ($self, $proto_group) = @_;
    my $factory = $self->factory();

    # SANITY CHECK: only if our Factory is updateable
    unless ($factory->can_update_store) {
        die "Cannot update read-only Group.\n";
    }

    # Have the Factory update the record
    $factory->Update($self, $proto_group);
}

# Delete the Group Homunculus from the system.
sub delete {
    my $self = shift;
    my $factory = $self->factory();
    $factory->Delete($self);
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

Socialtext::Group::Homunculus - Base class for Group Homunculus

=head1 DESCRIPTION

C<Socialtext::Group::Homunculus> implements a base class for a Group
Homunculus, from which all other Group Homunculi are to be derived from.

=head1 METHODS

=over

=item B<$group-E<gt>group_id()>

The internal Group Unique Identifier for the Group.

=item B<$group-E<gt>driver_key()>

The driver key for the Group Factory that this Group was created in.

=item B<$group-E<gt>driver_name()>

The driver name for the Group Factory that this Group was created in, which is
calculated from the C<driver_key>.

This driver name indicates which Group Factory type is responsible for
managing the Group (e.g. "Default", "LDAP", etc).

=item B<$group-E<gt>driver_id()>

The driver id for the Group Factory that this Group was created in, which is
calculated from the C<driver_key>

This driver id indicates a specific instance of the Group Factory type that is
responsible for managing the Group.

=item B<$group-E<gt>driver_unique_id()>

The unique identifier for the Group, I<within> the Group Factory that it is
being managed by.

=item B<$group-E<gt>driver_group_name()>

The display name for the Group, as specified by the Group Factory that the
Group is managed by.

=item B<$group-E<gt>account_id()>

The Account Id for the Account that this Group resides within.

=item B<$group-E<gt>account()>

Helper method, which returns the C<Socialtext::Account> object that represents
the Account for the C<account_id()> above.  

=item B<$group-E<gt>creation_datetime()>

A C<DateTime> object representing the date/time that the Group was created
at/on.

=item B<$group-E<gt>created_by_user_id()>

The User Id for the User who originally created the Group.

=item B<$group-E<gt>creator()>

Helper method, which returns the C<Socialtext::User> object that represents
the User for the C<created_by_user_id()> above.

=item B<$group-E<gt>cached_at()>

A C<DateTime> object representing the date/time on which the Group was last
cached.

=item B<$group-E<gt>is_system_managed()>

Returns true if the Group is system-managed (created by the System User),
returning false if the Group is user-managed.

=item B<$group-E<gt>factory()>

Helper method, which returns a Group Factory object representing the Factory
which manages this Group.

=item B<$group-E<gt>can_update_store()>

Returns true if the Group is managed by a Group Factory that has an updateable
store.  Returns false if the Group Factory is read-only.

Delegated to our Factory.

=item B<$group-E<gt>update_store(\%proto_group)>

Updates the Group with the information provided in the given C<\%proto_group>
hash-ref.

Throws a fatal exception if the Group Factory does not have an updateable
store.

=item B<$group-E<gt>delete()>

Deletes the Group from the local DB store.

This is simply a helper method, calling C<$self-E<gt>factory-E<gt>Delete($self)>.

=item B<$group-E<gt>expire()>

Expires the Group, so that it will be refreshed on next instantiation.

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
