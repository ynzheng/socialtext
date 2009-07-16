package Socialtext::Group::Factory;
# @COPYRIGHT@

use Moose::Role;
use Carp qw(croak);
use List::Util qw(first);
use Socialtext::Date;
use Socialtext::Exceptions qw(data_validation_error);
use Socialtext::Group::Homunculus;
use Socialtext::SQL qw(:exec :time);
use Socialtext::SQL::Builder qw(:all);
use Socialtext::l10n qw(loc);
use namespace::clean -except => 'meta';

with qw(
    Socialtext::Moose::SqlBuilder
    Socialtext::Moose::SqlBuilder::Role::DoesSqlInsert
    Socialtext::Moose::SqlBuilder::Role::DoesSqlSelect
    Socialtext::Moose::SqlBuilder::Role::DoesSqlUpdate
    Socialtext::Moose::SqlBuilder::Role::DoesSqlDelete
    Socialtext::Moose::SqlBuilder::Role::DoesColumnFiltering
);

sub Builds_sql_for { 'Socialtext::Group::Homunculus' };

has 'driver_key' => (
    is => 'ro', isa => 'Str',
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

has 'cache_lifetime' => (
    is => 'ro', isa => 'DateTime::Duration',
    lazy_build => 1,
);

# Methods we require downstream classes consuming this role to implement:
requires 'Create';
requires 'Update';
requires 'can_update_store';
requires '_build_cache_lifetime';

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

# Retrieves a Group from the DB, managed by this Factory instance, and returns
# a Group Homunculus object for the Group back to the caller.
sub GetGroupHomunculus {
    my ($self, %p) = @_;

    # Only concern ourselves with valid Db Columns
    my $where = $self->FilterValidColumns( \%p );

    # check DB for existing cached Group
    # ... if cached copy exists and is fresh, use that
    my $proto_group = $self->_get_cached_group($where);
    if ($proto_group && $self->_cached_group_is_fresh($proto_group)) {
        return $self->NewGroupHomunculus($proto_group);
    }

=begin PLACEHOLDER

    # cache non-existent or stale, refresh from data store
    # ... if unable to refresh, return empty-handed; we know nothing about
    # this Group.
    my $refreshed = $self->_lookup_group($proto_group);
    unless ($refreshed) {
        return;
    }

    # validate data retrieved from underlying data store
    $self->ValidateAndCleanData($proto_group, $refreshed);

    # update local cache with updated Group data
    $self->UpdateGroupRecord( {
        %{$refreshed},
        group_id    => $proto_group->{group_id},
        } );

    # merge the refreshed data back into the proto_group
    $proto_group = {
        %{$proto_group},
        %{$refreshed},
    };

    # create the homunculus, returning it back to the caller
    return $self->NewGroupHomunculus($proto_group);

=end PLACEHOLDER

=cut

}

# Looks up a Group in the DB, to see if we have a cached copy of it already.
sub _get_cached_group {
    my ($self, $where) = @_;

    # fetch the Group from the DB
    my $sth = $self->SqlSelectOneRecord( {
        where => {
            %{$where},
            driver_key  => $self->driver_key,
        },
    } );

    my $row = $sth->fetchrow_hashref();
    return $row;
}

# Checks to see if the cached Group data is fresh, using the cache lifetime
# for this Group Factory.
sub _cached_group_is_fresh {
    my ($self, $proto_group) = @_;
    my $now       = $self->Now();
    my $ttl       = $self->cache_lifetime();
    my $cached_at = sql_parse_timestamptz($proto_group->{cached_at});
    if (($cached_at + $ttl) > $now) {
        return 1;
    }
    return 0;
}

# Looks up the Group in the Factories underlying data store, and returns a new
# $refreshed_proto_group for the Group.  The provided $proto_group should be
# *UNTOUCHED*.
#sub _lookup_group {
#    my ($self, $proto_group) = @_;
#}

# Delete a Group object from the local DB.
sub Delete {
    my ($self, $group) = @_;
    $self->DeleteGroupRecord( $group->primary_key() );
}

# Deletes a Group record from the local DB.
sub DeleteGroupRecord {
    my ($self, $proto_group) = @_;

    # Only concern ourselves with valid Db Columns
    my $where = $self->FilterValidColumns( $proto_group );

    # DELETE the record in the DB
    my $sth = $self->SqlDeleteOneRecord( $where );
    return $sth->rows();
}

# Updates the local DB using the provided Group information
sub UpdateGroupRecord {
    my ($self, $proto_group) = @_;

    # set "cached_at" 
    $proto_group->{cached_at} ||= $self->Now();

    # Only concern ourselves with valid Db Columns
    my $valid = $self->FilterValidColumns( $proto_group );

    # Update is done against the primary key
    my $pkey = $self->FilterPrimaryKeyColumns( $valid );

    # Don't allow for primary key fields to be updated
    my $values = $self->FilterNonPrimaryKeyColumns( $valid );

    # If there's nothing to update, *don't*.
    return unless %{$values};

    # UPDATE the record in the DB
    my $sth = $self->SqlUpdateOneRecord( {
        values => $values,
        where  => $pkey,
    } );
}

# Expires a Group record in the local DB store
sub ExpireGroupRecord {
    my ($self, %p) = @_;
    return $self->UpdateGroupRecord( {
        %p,
        'cached_at' => '-infinity',
    } );
}

# Current date/time, as DateTime object
sub Now {
    return Socialtext::Date->now(hires=>1);
}

# Creates a new Group Homunculus
sub NewGroupHomunculus {
    my ($self, $proto_group) = @_;

    # determine type of Group Homunculus to create, and make sure that we've
    # got the appropriate module loaded.
    my ($driver_name, $driver_id) = split /:/, $proto_group->{driver_key};
    my $driver_class = join '::', Socialtext::Group->base_package, $driver_name;
    eval "require $driver_class";
    die "Couldn't load ${driver_class}: $@" if $@;

    # instantiate the homunculus, and return it back to the caller
    my $homey = $driver_class->new($proto_group);
    return $homey;
}

# Returns the next available Group Id
sub NewGroupId {
    return sql_nextval('groups___group_id');
}

# Creates a new Group object in the local DB store
sub NewGroupRecord {
    my ($self, $proto_group) = @_;

    # make sure that the Group has a "group_id"
    $proto_group->{group_id} ||= $self->NewGroupId();

    # new Group records default to being cached _now_.
    $proto_group->{cached_at} ||= $self->Now();

    # Only concern ourselves with valid Db Columns
    my $valid = $self->FilterValidColumns( $proto_group );

    # SANITY CHECK: need all required attributes
    my $missing =
        first { not defined $valid->{$_} }
        map   { $_->name }
        grep  { $_->is_required }
        $self->Sql_columns;
    die "need a $missing attribute to create a Group" if $missing;

    # INSERT the new record into the DB
    $self->SqlInsert( $valid );
}

# Validates a hash-ref of Group data, cleaning it up where appropriate.  If
# the data isn't valid, this method throws a
# Socialtext::Exception::Datavalidation exception.
sub ValidateAndCleanData {
    my ($self, $group, $p) = @_;
    my @errors;
    my @buffer;

    # are we "creating a new group", or "updating an existing group"
    my $is_create = defined $group ? 0 : 1;

    # figure out which attributes are required; they're marked as required but
    # *DON'T* include any attributes that we build lazily (our convention is
    # that lazily built attrs depend on the value of some other attr, so
    # they're not inherently required on their own; they're derived)
    my @required_fields =
        map { $_->name }
        grep { $_->is_required and !$_->is_lazy_build }
        $self->Builds_sql_for->meta->get_all_attributes;

    # new Groups *have* to have a Group Id
    $self->_validate_assign_group_id($p) if ($is_create);

    # new Groups *have* to have a creation date/time
    $self->_validate_assign_creation_datetime($p) if ($is_create);

    # new Groups *have* to have a creating User; default to a system-created
    # Group unless we've been told otherwise.
    $self->_validate_assign_created_by($p) if ($is_create);

    # trim fields, removing leading/trailing whitespace
    $self->_validate_trim_values($p);

    # check for presence of required attributes
    foreach my $field (@required_fields) {
        # field is required if either (a) we're creating a new Group record,
        # or (b) we were given a value to update it with
        if ($is_create or exists $p->{$field}) {
            @buffer= $self->_validate_check_required_field($field, $p);
            push @errors, @buffer if (@buffer);
        }
    }

    ### IF DATA FAILED TO VALIDATE, THROW AN EXCEPTION!
    if (@errors) {
        data_validation_error errors => \@errors;
    }
}

sub _validate_assign_group_id {
    my ($self, $p) = @_;
    $p->{group_id} ||= $self->NewGroupId();
    return;
}

sub _validate_assign_creation_datetime {
    my ($self, $p) = @_;
    $p->{creation_datetime} ||= $self->Now();
    return;
}

sub _validate_trim_values {
    my ($self, $p) = @_;
    map { $p->{$_} = Socialtext::String::trim($p->{$_}) }
        grep { !ref($p->{$_}) }
        grep { defined $p->{$_} }
        map  { $_->name }
        $self->Sql_columns;
    return;
}

sub _validate_check_required_field {
    my ($self, $field, $p) = @_;
    unless ((defined $p->{$field}) and (length($p->{$field}))) {
        return loc('[_1] is a required field.',
            ucfirst Socialtext::Data::humanize_column_name($field)
        );
    }
    return;
}

sub _validate_assign_created_by {
    my ($self, $p) = @_;
    # unless we were told who is creating this Group, presume that it's being
    # created by the System-User
    $p->{created_by_user_id} ||= Socialtext::User->SystemUser()->user_id();
    return;
}

no Moose::Role;
1;

=head1 NAME

Socialtext::Group::Factory - Group Factory Role

=head1 SYNOPSIS

  use Socialtext::Group;

  # instantiating a Group Factory
  $factory = Socialtext::Group->Factory(driver_key => $driver_key);

=head1 DESCRIPTION

C<Socialtext::Group::Factory> provides an I<abstract> Group Factory Role,
which can be consumed by your own Group Factory implementation.

=head1 METHODS

=over

=item B<$factory-E<gt>driver_key()>

The unique driver key for the Group factory.

=item B<$factory-E<gt>driver_name()>

The driver name, which is calculated from the C<driver_key>.

The driver name indicates which Group Factory type is instantiated (e.g.
"Default", "LDAP", etc).

=item B<$factory-E<gt>driver_id()>

The driver id for the Group Factory, which is calculated from the
C<driver_key>.

The driver id indicates a specific instance of this type of Group Factory.

=item B<$factory-E<gt>cache_lifetime()>

The cache TTL for Groups being managed by this Group Factory, as a
C<DateTime::Duration> object.

No default cache lifetime is provided or defined; you must implement the
C<_build_cache_lifetime()> builder method in your concrete Factory
implementation.

=item B<$factory-E<gt>Create(\%proto_group)>

Attempts to create a new Group object in the data store, using the information
provided in the given C<\%proto_group> hash-ref.

Factories consuming this Role B<MUST> implement this method, and are
responsible for ensuring that they are doing proper validation/cleaning of the
data prior to creating the Group.

If your Factory is read-only and is not updateable, simply implement a stub
method which throws an exception to indicate error.

=item B<$factory-E<gt>Update($group, \%proto_group)>

Updates the C<$group> with the information provided in the C<\%proto_group>
hash-ref.

Factories consuming this Role B<MUST> implement this method, and are
responsible for ensuring that they are doing proper validation/cleaning of the
data prior to updating the underlying data store.

If your Factory is read-only and is not updateable, simply implement a stub
method which throws an exception to indicate error.

=item B<$factory-E<gt>can_update_store()>

Returns true if the data store behind this Group Factory is updateable,
returning false if the data store is read-only.

Factories consuming this Role B<MUST> implement this method to indicate if
they're updateable or not.

=item B<$factory-E<gt>GetGroupHomunculus(group_id =E<gt> $group_id)>

Retrieves the Group record from the local DB, turns it into a Group Homunculus
object, and returns that Group Homunculus back to the caller.

The Group record found in the DB is subject to freshness checks, and if it is
determined that the Group data is stale the Factory will be asked to refresh
the Group from its underlying data store (and the local cached copy will be
updated accordingly).

=item B<$factory-E<gt>UpdateGroupRecord(\%proto_group)>

Updates an existing Group record in the local DB store, based on the
information provided in the C<\%proto_group> hash-ref.

This C<\%proto_group> hash-ref B<MUST> contain the C<group_id> of the Group
record that we are updating in the DB.

The C<cached_at> time for the record will be updated to "now" by default.  If
you wish to preserve the existing C<cached_at> time, be sure to pass that in
as part of the data in C<\%proto_group>.

=item B<$factory-E<gt>Delete($group)>

Deletes a Group object from the local DB store.

This is just a helper method which calls C<$factory-E<gt>DeleteGroupRecord()>
under the hood.

=item B<$factory-E<gt>DeleteGroupRecord(\%proto_group)>

Deletes a Group record from the local DB store, based on the informaiton
provided in the C<\%proto_group> hash-ref.

This C<\%proto_group> hash-ref B<MUST> contain the C<group_id> of the Group
record that we are deleting in the DB.

Deletion is B<ONLY> performed for the local DB representation of the Group.
In the case of externally sourced Groups (e.g. LDAP), B<no> deletion is pushed
out to the external data store.  This allows for us to delete the local
representation of the Group, without actually destroying the original external
Group definition.

This method returns true on success, false on failure.

=item B<$factory-E<gt>ExpireGroupRecord(group_id =E<gt> $group_id)>

Expires the Group in our local DB.  Next time the Group is instantiated, the
Factory managing for the Group will refresh the Group information from its
data store.

=item B<$factory-E<gt>Now()>

Returns the current date/time in hi-res, as a C<DateTime> object.

=item B<$factory-E<gt>NewGroupHomunculus(\%proto_group)>

Creates a new Group Homunculus object based on the information provided in the
C<\%proto_group> hash-ref.

The C<\%proto_group> B<must> contain all of the attributes required for the
Group Homunculus to be instantiated, for that specific Homunculus type.

=item B<$factory-E<gt>NewGroupId()>

Returns a new unique Group Id.  Id returned is B<guaranteed> to be unique.

=item B<$factory-E<gt>NewGroupRecord(\%proto_group)>

Creates a new Group record in the local DB store, based on the information
provided in the C<\%proto_group> hash-ref.

A unique C<group_id> will be calculated for the Group if one is not available
in the C<\%proto_group>.

Groups default to being C<cached_at> "now", unless specified otherwise in the
C<\%proto_group>.

=item B<$factory-E<gt>ValidateAndCleanData($group, \%proto_group)>

Validates the data provided in the C<\%proto_group> hash-ref, with respect to
any existing C<$group> that we may (or may not) be updating.

If a C<$group> is provided, validation is performed as "we are updating that
Group with the data provided in the C<\%proto_group>".

If no C<$group> is provided, validation is performed as "we are validating
data for the purpose of creating a new Group".

In the event of error, this method throws a
C<Socialtext::Exception::DataValidation> error.

Validation/cleanup performed:

=over

=item *

New Groups must have a C<group_id>, and a unique Group Id is calculated
automatically if it is not provided.

Only applicable if you are I<creating> a new Group; if you are updating a
Group it is presumed that you already have a unique Group Id for the Group.

=item *

New Groups must have a <creation_datetime>, which defaults to "now" unless
provided.

Only applicable if you are I<creating> a new Group.

=item *

New Groups must have a <created_by_user_id>, which defaults to "the System
User" unless provided.

Only applicable if you are I<creating> a new Group.

=item *

All attributes are trimmed of leading/trailing whitespace.

=item *

Check for presence of all required attributes, as defined by the Group
Homunculus.

When creating a new Group, validation is performed against the baseline set of
attributes as defined in C<Socialtext::Group::Homunculus>.

When updating an existing Group, validation is performed against the
attributes defined by the provided Group Homunculus object.

=back

=back

=head1 IMPLEMENTING A GROUP FACTORY

In order to consume this Group Factory Role and implement a concrete Group
Factory, you need to provide implementations for the following methods:

=over

=item Create(\%proto_group)

=item Update($group, \%proto_group)

=item can_update_store()

=item _build_cache_lifetime()

=back

Please refer to the L</METHODS> section above for more information on how
these methods are intended to behave.

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
