package Socialtext::GroupWorkspaceRoleFactory;
# @COPYRIGHT@

use MooseX::Singleton;
use Carp qw(croak);
use Socialtext::Events;
use Socialtext::Log qw(st_log);
use Socialtext::SQL qw(:exec);
use Socialtext::SQL::Builder qw(:all);
use Socialtext::Role;
use Socialtext::Timer;
use Socialtext::GroupWorkspaceRole;
use namespace::clean -except => 'meta';

sub GetGroupWorkspaceRole {
    my ($self, %p) = @_;

    # make sure we have all primary key values, and build up the SQL to search
    # for that specific key
    my %pkey = $self->_ensure_pkey(\%p);

    # map GWR attributes to DB columns
    my ($clause, @bindings) = $self->_pkey_where_clause(%pkey);

    # fetch the GWR from the DB
    my $sql = qq{
        SELECT role_id
          FROM group_workspace_role
         WHERE $clause;
    };
    my $role_id = sql_singlevalue($sql, @bindings);
    return undef unless $role_id;

    # create the GWR object
    return Socialtext::GroupWorkspaceRole->new( {
        %pkey,
        role_id  => $role_id,
    } );
}

sub CreateRecord {
    my ($self, $proto_gwr) = @_;
    my @attrs = Socialtext::GroupWorkspaceRole->meta->get_all_column_attributes;

    # SANITY CHECK: need all required attributes
    foreach my $attr (@attrs) {
        my $attr_name = $attr->name;
        if (($attr->is_required) && (!defined $proto_gwr->{$attr_name})) {
            die "need a $attr_name attribute to create a GroupWorkspaceRole";
        }
    }

    # map GWR attributes to SQL INSERT args
    my %insert_args =
        map { $_->column_name => $proto_gwr->{ $_->name } } @attrs;

    # INSERT the new record into the DB
    sql_insert('group_workspace_role', \%insert_args);

    $self->_emit_event($proto_gwr, 'create_role');
}

sub Create {
    my ($self, $proto_gwr) = @_;
    my $timer = Socialtext::Timer->new();

    $proto_gwr->{role_id} ||= $self->DefaultRoleId();
    $self->CreateRecord($proto_gwr);

    my $gwr = $self->GetGroupWorkspaceRole(%{$proto_gwr});
    $self->_record_log_entry('ASSIGN', $gwr, $timer);
    return $gwr;
}

sub UpdateRecord {
    my ($self, $proto_gwr) = @_;

    # SANITY CHECK: need to know which UG* we're updating
    my %pkey = $self->_ensure_pkey($proto_gwr);

    # map GWR attributes to SQL UPDATE args
    my %update_args =
        map { $_->column_name => $proto_gwr->{ $_->name } }
        grep { exists $proto_gwr->{ $_->name } }
        Socialtext::GroupWorkspaceRole->meta->get_all_column_attributes;

    my $sth = sql_update('group_workspace_role', \%update_args, [keys %pkey]);

    my $did_update = ($sth && $sth->rows) ? 1 : 0;
    $self->_emit_event($proto_gwr, 'update_role') if $did_update;
    return $did_update;
}

sub Update {
    my ($self, $group_workspace_role, $proto_gwr) = @_;
    my $timer = Socialtext::Timer->new();

    # update the record for this GWR in the DB
    my $updates_ref = {
        %{$proto_gwr},
        group_id     => $group_workspace_role->group_id,
        workspace_id => $group_workspace_role->workspace_id,
    };
    my $did_update = $self->UpdateRecord($updates_ref);

    if ($did_update) {
        # merge the updates back into the GWR object
        foreach my $attr (keys %{$updates_ref}) {
            # can't update pkey attrs
            my $meta_attr =
                $group_workspace_role->meta->find_attribute_by_name($attr);
            next if ($meta_attr->is_primary_key());

            # update non pkey attrs
            my $setter = "_$attr";
            $group_workspace_role->$setter( $updates_ref->{$attr} );
        }

        $self->_record_log_entry('CHANGE', $group_workspace_role, $timer);
    }

    return $group_workspace_role;
}

sub DeleteRecord {
    my ($self, $proto_gwr) = @_;

    # SANITY CHECK: need to know which UG* we're updating
    my %pkey = $self->_ensure_pkey($proto_gwr);

    # map GWR attributes to SQL DELETE args
    my ($clause, @bindings) = $self->_pkey_where_clause(%pkey);

    my $sql = qq{DELETE FROM group_workspace_role WHERE $clause};
    my $sth = sql_execute($sql, @bindings);

    my $did_delete = $sth->rows();
    $self->_emit_event($proto_gwr, 'delete_role') if $did_delete;

    return $did_delete;
}

sub Delete {
    my ($self, $gwr) = @_;
    my $timer = Socialtext::Timer->new();
    my $did_delete = $self->DeleteRecord( {
        group_id     => $gwr->group_id,
        workspace_id => $gwr->workspace_id,
        } );
    $self->_record_log_entry('REMOVE', $gwr, $timer) if $did_delete;
    return $did_delete;
}

sub ByGroupId {
    my $self_or_class = shift;
    my $group_id      = shift;
    my $closure       = shift;

    # introspect the names of the DB columns for these attributes
    my $meta = Socialtext::GroupWorkspaceRole->meta();
    my ($group_column, $ws_column) =
        map { $meta->find_attribute_by_name($_)->column_name() }
        qw(group_id workspace_id);

    # build the SQL used to get the GWRs for this Group Id
    my $sql = qq{
        SELECT *
          FROM group_workspace_role
         WHERE $group_column = ?
      ORDER BY $ws_column
    };

    # go get the list of GWRs
    return $self_or_class->_GwrCursor( $sql, [$group_id], $closure );
}

sub ByWorkspaceId {
    my $self_or_class = shift;
    my $workspace_id  = shift;
    my $closure       = shift;

    # introspect the names of the DB columns for these attributes
    my $meta = Socialtext::GroupWorkspaceRole->meta();
    my ($group_column, $ws_column) =
        map { $meta->find_attribute_by_name($_)->column_name() }
        qw(group_id workspace_id);

    # build the SQL used to get the GWRs for this Workspace Id
    my $sql = qq{
        SELECT *
          FROM group_workspace_role
         WHERE $ws_column = ?
      ORDER BY $group_column
    };

    # go get the list of GWRs
    return $self_or_class->_GwrCursor( $sql, [$workspace_id], $closure );
}

# When calling _GwrCursor(), your SQL *MUST* include the "group_id",
# "workspace_id", and "role_id" columns in the SELECT.
sub _GwrCursor {
    my $self_or_class = shift;
    my $sql           = shift;
    my $bindings      = shift;
    my $closure       = shift;

    my $sth = sql_execute($sql, @$bindings);
    return Socialtext::MultiCursor->new(
        iterables => [ $sth->fetchall_arrayref( {} ) ],
        apply     => sub {
            my $row = shift;
            my $gwr = Socialtext::GroupWorkspaceRole->new($row);
            return ( $closure ) ? $closure->($gwr) : $gwr;
        },
    );
}

sub _emit_event {
    my ($self, $proto_gwr, $action) = @_;

    # System managed groups are acted on by the System User.
    #
    # non-system managed groups are currently unscoped/unsupported.
    my $group = Socialtext::Group->GetGroup(group_id => $proto_gwr->{group_id});
    my $actor = $group->is_system_managed()
                ? Socialtext::User->SystemUser()
                : die "unable to determine event actor";

    # Record the event
    Socialtext::Events->Record( {
        event_class => 'workspace',
        action      => $action,
        actor       => $actor,
        context     => $proto_gwr,
    } );
}

sub _ensure_pkey {
    my ($self, $proto_gwr) = @_;
    my @attrs = Socialtext::GroupWorkspaceRole->meta->get_all_column_attributes;
    my %pkey;
    foreach my $attr (@attrs) {
        next unless $attr->is_primary_key();
        my $attr_name = $attr->name();
        unless ($proto_gwr->{$attr_name}) {
            croak "missing required primary key attribute '$attr_name'";
        }
        $pkey{$attr_name} = $proto_gwr->{$attr_name};
    }
    return %pkey;
}

sub _pkey_where_clause {
    my ($self, %pkey) = @_;

    my $meta = Socialtext::GroupWorkspaceRole->meta;
    my %args =
        map { $_->column_name => $pkey{ $_->name } }
        map { $meta->find_attribute_by_name($_) }
        keys %pkey;

    # build the SQL to do the DELETE
    my $clause =
        join ' AND ',
        map { "$_ = ?" }
        keys %args;
    my @bindings = values %args;

    return ($clause, @bindings);
}

sub _record_log_entry {
    my ($self, $action, $gwr, $timer) = @_;
    my $msg = "$action,GROUP_WORKSPACE_ROLE,"
        . 'role:' . $gwr->role->name . ','
        . 'group:' . $gwr->group->driver_group_name
            . '(' . $gwr->group->group_id . '),'
        . 'workspace:' . $gwr->workspace->name
            . '(' . $gwr->workspace->workspace_id . '),'
        . '[' . $timer->elapsed . ']';
    st_log->info($msg);
}

sub DefaultRole {
    Socialtext::Role->Member();
}

sub DefaultRoleId {
    DefaultRole()->role_id();
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

Socialtext::GroupWorkspaceRoleFactory - Factory for ST::GroupWorkspaceRole objects

=head1 SYNOPSIS

  use Socialtext::GroupWorkspaceRoleFactory;

  $factory = Socialtext::GroupWorkspaceRoleFactory->instance();

  # create a new GWR
  $gwr = $factory->Create( {
      group_id     => $group_id,
      workspace_id => $workspace_id,
      role_id      => $role_id,
  } );

  # retrieve a GWR
  $gwr = $factory->GetGroupWorkspaceRole(
      group_id     => $group_id,
      workspace_id => $workspace_id,
  );

  # update a GWR
  $factory->Update($gwr, \%updates_ref);

  # delete a GWR
  $factory->Delete($gwr);

=head1 DESCRIPTION

C<Socialtext::GroupWorkspaceRoleFactory> is used to manipulate the DB store
for C<Socialtext::GroupWorkspaceRole> objects.

=head1 METHODS

=over

=item B<$factory-E<gt>GetGroupWorkspaceRole(PARAMS)>

Looks for an existing record in the group_workspace_role table matching PARAMS
and returns a C<Socialtext::GroupWorkspaceRole> representing that row, or
undef if it can't find a match.

PARAMS I<must> contain:

=over

=item * group_id =E<gt> $group_id

=item * workspace_id =E<gt> $workspace_id

=back

=item B<$factory-E<gt>CreateRecord(\%proto_gwr)>

Create a new entry in the group_workspace_role table, if possible, and return
the corresponding C<Socialtext::GroupWorkspaceRole> object on success.

C<\%proto_gwr> I<must> include the following:

=over

=item * group_id =E<gt> $group_id

=item * workspace_id =E<gt> $workspace_id

=item * role_id =E<gt> $role_id

=back

=item B<$factory-E<gt>Create(\%proto_gwr)>

Create a new entry in the group_workspace_role table, a simplfied wrapper
around C<CreateRecord>.

C<\%proto_gwr> I<must> include the following:

=over

=item * group_id =E<gt> $group_id

=item * workspace_id =E<gt> $workspace_id

=back

It can I<optionally> include:

=over

=item * role_id =E<gt> $role_id

=back

If no C<$role_id> is provided, a default role will be used instead.  Refer to
C<DefaultRoleId()> for details.

=item B<$factory-E<gt>UpdateRecord(\%proto_gwr)>

Updates an existing group_workspace_role record in the DB, based on the
information provided in the C<\%proto_gwr> hash-ref.  Returns true if a record
was updated in the DB, returning false otherwise (e.g. if the update was
effectively "no change").

This C<\%proto_gwr> hash-ref B<MUST> contain the C<group_id> and
C<workspace_id> of the GWR that we are updating in the DB.

If you attempt to update a non-existing GWR, this method fails silently; no
exception is thrown, B<but> no data is updated/inserted in the DB (as it
didn't exist there in the first place).

=item B<$factory-E<gt>Update($gwr, \%proto_gwr)>

Updates the given C<$gwr> object with the information provided in the
C<\%proto_gwr> hash-ref.

Returns the updated C<$gwr> object back to the caller.

=item B<$factory-E<gt>DeleteRecord(\%proto_gwr)>

Deletes the group_workspace_role record from the DB, as described by the
provided C<\%proto_gwr> hash-ref.

Returns true if a record was deleted, false otherwise.

=item B<$factory-E<gt>Delete($gwr)>

Deletes the C<$gwr> from the DB.

Helper method which calls C<DeleteRecord()>.

=item B<$factory-E<gt>ByGroupId($group_id, $closure)>

Get a C<Socialtext::MultiCursor> of GWR's for a group.

This method takes an optional C<$closure> PARAM that can be used to maniulate
the GWR before it gets passed back with C<Socialtext::MultiCursor->next()>.
This can be used, for example to return only the C<workspace> attribute of the
GWR.

=item B<$factory-E<gt>ByWorkspaceId($workspace_id)>

Get a C<Socialtext::MultiCursor> of GWR's for a Workspace.

This method takes an optional C<$closure> PARAM that can be used to maniulate
the GWR before it gets passed back with C<Socialtext::MultiCursor->next()>.
This can be used, for example to return only the C<group> attribute of the
GWR.

=item B<$factory-E<gt>DefaultRole()>

Returns the C<Socialtext::Role> object for the default Role being used.

=item B<$factory-E<gt>DefaultRoleId()>

Get the ID for the default Role being used.

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
