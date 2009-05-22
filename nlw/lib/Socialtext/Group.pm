package Socialtext::Group;
# @COPYRIGHT@

use Moose;
use List::Util qw(first);
use Socialtext::AppConfig;
use namespace::clean -except => 'meta';

###############################################################################
# The "Group" equivalent to a User Homunculus.
has 'homunculus' => (
    is => 'ro', isa => 'Socialtext::Group::Homunculus',
    required => 1,
    handles => [qw(
        group_id
        driver_key
        driver_name
        driver_id
        driver_unique_id
        driver_group_name
        account_id
        account
        creation_datetime
        created_by_user_id
        creator
        cached_at
        is_system_managed
        expire
        can_update_store
        update_store
    )],
);

###############################################################################
sub Drivers {
    my $drivers = Socialtext::AppConfig->group_factories();
    return split /;/, $drivers;
}

###############################################################################
sub Factory {
    my ($class, %p) = @_;
    my $driver_name = $p{driver_name};
    my $driver_id   = $p{driver_id};
    my $driver_key  = $p{driver_key};
    if ($driver_key) {
        ($driver_name, $driver_id) = split /;/, $driver_key;
    }

    my $driver_class = join '::', $class->base_package(), $driver_name, 'Factory';
    eval "require $driver_class";
    die "couldn't load $driver_class: $@" if $@;
    return $driver_class->new(driver_id => $driver_id);
}

###############################################################################
sub Create {
    my ($class, $proto_group) = @_;

    # find first updateable factory
    my $factory =
        first { $_->can_update_store }
        map { $class->Factory(driver_key => $_) }
        $class->Drivers();
    unless ($factory) {
        die "No writable Group factories configured.";
    }

    # ask that factory to create the Group
    my $group = $factory->Create($proto_group);
    return $group;
}

###############################################################################
# Base package for Socialtext Group infrastructure.
sub base_package {
    return __PACKAGE__;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

Socialtext::Group - Socialtext Group object

=head1 SYNOPSIS

  use Socialtext::Group;

  # get a list of all registered Group factories/drivers
  @drivers = Socialtext::Group->Drivers();

  # instantiate a specific Group Factory
  $factory = Socialtext::Group->Factory(driver_key => $driver_key);
  $factory = Socialtext::Group->Factory(
    driver_name => $driver_name,
    driver_id   => $driver_id,
    );

  # create a new Group
  $group = Socialtext::Group->Create( \%proto_group );

=head1 DESCRIPTION

This class provides methods for dealing with Groups.

=head1 METHODS

=over

=item B<Socialtext::Group-E<gt>Drivers()>

Returns a list of registered Group factories/drivers back to the caller, as a
list of their "driver_key"s.  These "driver_key"s can be used to instantiate a
gactory by calling C<Socialtext::Group-E<gt>Factory()>.

=item B<Socialtext::Group-E<gt>Factory(%opts)>

Instantiates a Group Factory, as defined by the provided C<%opts>.

Valid instantiation C<%opts> include:

=over

=item driver_key =E<gt> $driver_key

Factory instantiation via driver key (which contains both the name of the
driver and its id).

=item driver_name =E<gt> $driver_name, driver_id =E<gt> $driver_id

Factory instantiation via driver name+id.

=back

=item B<Socialtext::Group-E<gt>Create(\%proto_group)>

Attempts to create a Group with the given C<\%proto_group> hash-ref, returning
the newly created Group object back to the caller.  The Group will be created
in the first updateable Group Factory store, as found in the list of
C<Drivers()>.

For more information on the required attributes for a Group, please refer to
L<Socialtext::Group::Factory> and its C<Create()> method.

=item B<$group-E<gt>homunculus()>

Returns the Group Homunculus for the Group.

=item B<$group-E<gt>group_id()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>driver_key()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>driver_name()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>driver_id()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>driver_unique_id()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>driver_group_name()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>account_id()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>account()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>creation_datetime()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>created_by_user_id()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>creator()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>cached_at()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>is_system_managed()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>expire()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>can_update_store()>

Delegated to C<Socialtext::Group::Homunculus>.

=item B<$group-E<gt>update_store()>

Delegated to C<Socialtext::Group::Homunculus>.

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut