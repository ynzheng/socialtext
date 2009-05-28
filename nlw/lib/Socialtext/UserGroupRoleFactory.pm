package Socialtext::UserGroupRoleFactory;
# @COPYRIGHT@

use MooseX::Singleton;
use Carp qw(croak);
use Socialtext::Events;
use Socialtext::SQL qw/:exec/;
use Socialtext::SQL::Builder qw(:all);
use Socialtext::Role;
use Socialtext::UserGroupRole;
use namespace::clean -except => 'meta';

sub GetUserGroupRole {
    my ($self, %p) = @_;

    # make sure we have all primary key values, and build up the SQL to search
    # for that specific key
    my %pkey = $self->_ensure_pkey(\%p);

    # map UGR attributes to DB columns
    my ($clause, @bindings) = $self->_pkey_where_clause(%pkey);

    # fetch the UGR from the DB
    my $sql = qq{
        SELECT role_id
          FROM user_group_role
         WHERE $clause;
    };
    my $role_id = sql_singlevalue($sql, @bindings);
    return undef unless $role_id;

    # create the UGR object
    return Socialtext::UserGroupRole->new( {
        %pkey,
        role_id  => $role_id,
    } );
}

sub CreateRecord {
    my ($self, $proto_ugr) = @_;
    my @attrs = Socialtext::UserGroupRole->meta->get_all_column_attributes;

    # SANITY CHECK: need all required attributes
    foreach my $attr (@attrs) {
        my $attr_name = $attr->name;
        if (($attr->is_required) && (!defined $proto_ugr->{$attr_name})) {
            die "need a $attr_name attribute to create a UserGroupRole";
        }
    }

    # map UGR attributes to SQL INSERT args
    my %insert_args =
        map { $_->column_name => $proto_ugr->{ $_->name } } @attrs;

    # INSERT the new record into the DB
    sql_insert('user_group_role', \%insert_args);

    $self->_emit_event($proto_ugr, 'create_role');
}

sub Create {
    my ($self, $proto_ugr) = @_;
    $proto_ugr->{role_id} ||= $self->DefaultRoleId();
    $self->CreateRecord($proto_ugr);
    return $self->GetUserGroupRole(%{$proto_ugr});
}

sub UpdateRecord {
    my ($self, $proto_ugr) = @_;

    # SANITY CHECK: need to know which UG* we're updating
    my %pkey = $self->_ensure_pkey($proto_ugr);

    # map UGR attributes to SQL UPDATE args
    my %update_args =
        map { $_->column_name => $proto_ugr->{ $_->name } }
        grep { exists $proto_ugr->{ $_->name } }
        Socialtext::UserGroupRole->meta->get_all_column_attributes;

    my $sth = sql_update('user_group_role', \%update_args, [keys %pkey]);

    $self->_emit_event($proto_ugr, 'update_role')
        if ($sth && $sth->rows);
}

sub Update {
    my ($self, $user_group_role, $proto_ugr) = @_;

    # update the record for this UGR in the DB
    my $updates_ref = {
        %{$proto_ugr},
        user_id  => $user_group_role->user_id,
        group_id => $user_group_role->group_id,
    };
    $self->UpdateRecord($updates_ref);

    # merge the updates back into the UGR object
    foreach my $attr (keys %{$updates_ref}) {
        # can't update pkey attrs
        my $meta_attr = $user_group_role->meta->get_attribute($attr);
        next if ($meta_attr->is_primary_key());

        # update non pkey attrs
        my $setter = "_$attr";
        $user_group_role->$setter( $updates_ref->{$attr} );
    }
    return $user_group_role;
}

sub DeleteRecord {
    my ($self, $proto_ugr) = @_;

    # SANITY CHECK: need to know which UG* we're updating
    my %pkey = $self->_ensure_pkey($proto_ugr);

    # map UGR attributes to SQL DELETE args
    my ($clause, @bindings) = $self->_pkey_where_clause(%pkey);

    my $sql = qq{DELETE FROM user_group_role WHERE $clause};
    my $sth = sql_execute($sql, @bindings);

    $self->_emit_event($proto_ugr, 'delete_role')
        if ($sth->rows);

    return $sth->rows();
}

sub Delete {
    my ($self, $ugr) = @_;
    $self->DeleteRecord( {
        user_id  => $ugr->user_id,
        group_id => $ugr->group_id,
        } );
}

sub _emit_event {
    my ($self, $proto_ugr, $action) = @_;

    # System managed groups are acted on by the System User.
    #
    # non-system managed groups are currently unscoped/unsupported.
    my $group = Socialtext::Group->GetGroup(group_id => $proto_ugr->{group_id});
    my $actor = $group->is_system_managed()
                ? Socialtext::User->SystemUser()
                : die "unable to determine event actor";

    # Record the event
    Socialtext::Events->Record( {
        event_class => 'group',
        action      => $action,
        actor       => $actor,
        context     => $proto_ugr,
    } );
}

sub _ensure_pkey {
    my ($self, $proto_ugr) = @_;
    my @attrs = Socialtext::UserGroupRole->meta->get_all_column_attributes;
    my %pkey;
    foreach my $attr (@attrs) {
        next unless $attr->is_primary_key();
        my $attr_name = $attr->name();
        unless ($proto_ugr->{$attr_name}) {
            croak "missing required primary key attribute '$attr_name'";
        }
        $pkey{$attr_name} = $proto_ugr->{$attr_name};
    }
    return %pkey;
}

sub _pkey_where_clause {
    my ($self, %pkey) = @_;

    my $meta = Socialtext::UserGroupRole->meta;
    my %args =
        map { $_->column_name => $pkey{ $_->name } }
        map { $meta->get_attribute($_) }
        keys %pkey;

    # build the SQL to do the DELETE
    my $clause =
        join ' AND ',
        map { "$_ = ?" }
        keys %args;
    my @bindings = values %args;

    return ($clause, @bindings);
}

sub DefaultRoleId {
    Socialtext::Role->new( name => 'member' )->role_id();
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

=head1 SYNOPSIS

  use Socialtext::UserGroupRoleFactory;

  $factory = Socialtext::UserGroupRoleFactory->instance();

  $ugr = $factory->Create( {
      user_id   => $user_id,
      group_id  => $group_id,
      role_id   => $role_id,
  } );

=head1 DESCRIPTION

C<Socialtext::UserGroupRoleFactory> is used to manipulate the DB store for C<Socialtext::UserGroupRole> objects.

=head1 METHODS

=over

=item $factory-E<gt>GetUserGroupRole(PARAMS)

Looks for an existing record in the user_group_role table matching PARAMS and
returns a C<Socialtext::UserGroupRole> representing that row, or undef if it
can't find a match.

PARAMS I<must> be:

=over 8

=item * user_id =E<gt> $user_id

=item * group_id =E<gt> $group_id

=back

=item $factory-E<gt>CreateRecord($proto_ugr)

Create a new entry in the user_group_role table, if possible, and return the corresponding C<Socialtext::UserGroupRole> object on success.

C<$proto_ugr> I<must> include the following:

=over 8

=item * user_id =E<gt> $user_id

=item * group_id =E<gt> $group_id

=item * role_id =E<gt> $role_id

=back

=item $factory-E<gt>Create($proto_ugr)

Create a new entry in the user_group_role table, a simplfied wrapper around
C<CreateRecord>.

C<$proto_ugr> I<must> include the following:

=over 8

=item * user_id =E<gt> $user_id

=item * group_id =E<gt> $group_id

=back

It can I<optionally> include:

=over 8

=item * role_id =E<gt> $role_id

=back

If C<$role_id> is not included, we will use a default role. See the
C<DefaultRoleId> sub for details.

=item $factory-E<gt>UpdateRecord(\%proto_ugr)

Updates an existing user_group_role record in the DB, based on the information
provided in the C<\%proto_ugr> hash-ref.

This C<\%proto_ugr> hash-ref B<MUST> contain the C<user_id> and C<group_id> of
the UGR that we are updating in the DB.

If you attempt to update a non-existing UGR, this method fails silently; no
exception is thrown, B<but> no data is updated/inserted in the DB (as it
didn't exist there in the first place).

=item $factory-E<gt>Update($ugr, \%proto_ugr)

Updates the given C<$ugr> object with the information provided in the
C<\%proto_ugr> hash-ref.

Returns the updated C<$ugr> object back to the caller.

=item $factory-E<gt>DeleteRecord(\%proto_ugr)

Deletes the user_group_role record from the DB, as described by the provided
C<\%proto_ugr> hash-ref.

Returns true if a record was deleted, false otherwise.

=item $factory-E<gt>Delete($ugr)

Deletes the C<ugr> from the DB.

Helper method which calls C<DeleteRecord()>.

=item $factory-E<gt>DefaultRoleId()

Get the ID for the default Role being  used.

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut

