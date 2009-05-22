package Socialtext::Group::Default::Factory;
# @COPYRIGHT@

use Moose;
use namespace::clean -except => 'meta';
use DateTime::Duration;

with 'Socialtext::Group::Factory';

has '+driver_key' => (
    default => 'Default',
);

# the Default store *is* updateable
sub can_update_store { 1 }

# creates a new Group, and stores it in the data store
sub Create {
    my ($self, $proto_group) = @_;

    # validate the data we were provided
    $proto_group->{driver_key}       = $self->driver_key();
    $proto_group->{group_id}         = $self->NewGroupId();
    $proto_group->{driver_unique_id} = $proto_group->{group_id};
    $self->ValidateAndCleanData(undef, $proto_group);

    # create a new record for this Group in the DB
    $self->NewGroupRecord($proto_group);

    # create a homunculus, and return that back to the caller
    return $self->NewGroupHomunculus($proto_group);
}

# effectively infinite cache lifetime
sub _build_cache_lifetime {
    return DateTime::Duration->new(years => 1000);
}

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Socialtext::Group::Default::Factory - Internally sourced Group Factory

=head1 SYNOPSIS

  use Socialtext::Group;

  $factory = Socialtext::Group->Factory(driver_key => 'Default');

=head1 DESCRIPTION

C<Socialtext::Group::Default::Factory> provides an implementation of a Group
Factory that is sourced internally by Socialtext (e.g. Groups are defined by
the local DB).

Consumes the C<Socialtext::Group::Factory> Role.

=head1 METHODS

=over

=item B<$factory-E<gt>can_update_store()>

Returns true; the Default Group Factory B<is> updateable.

=item B<$factory-E<gt>Create(\%proto_group)>

Attempts to create a new Group based on the information provided in the
C<\%proto_group> hash-ref.

Implements C<Create()> as specified by C<Socialtext::Group::Factory>; please
refer to L<Socialtext::Group::Factory> for more information.

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
