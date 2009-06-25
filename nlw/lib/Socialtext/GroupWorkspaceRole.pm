package Socialtext::GroupWorkspaceRole;
# @COPYRIGHT@

use Moose;
use Socialtext::MooseX::SQL;
use namespace::clean -except => 'meta';

has_column 'group_id' => (
    is => 'rw', isa => 'Int',
    writer => '_group_id',
    trigger => \&_set_group_id,
    primary_key => 1,
);

has 'group' => (
    is => 'ro', isa => 'Socialtext::Group',
    lazy_build => 1,
);

has_column 'workspace_id' => (
    is => 'rw', isa => 'Int',
    writer => '_workspace_id',
    trigger => \&_set_workspace_id,
    primary_key => 1,
);

has 'workspace' => (
    is => 'ro', isa => 'Socialtext::Workspace',
    lazy_build => 1,
);

has_column 'role_id' => (
    is => 'rw', isa => 'Int',
    writer => '_role_id',
    trigger => \&_set_role_id,
    required => 1,
);

has 'role' => (
    is => 'ro', isa => 'Socialtext::Role',
    lazy_build => 1,
);

sub _set_group_id {
    my $self = shift;
    $self->clear_group();
}

sub _build_group {
    my $self = shift;
    require Socialtext::Group;          # lazy-load
    my $group_id = $self->group_id();
    my $group    = Socialtext::Group->GetGroup(group_id => $group_id);
    unless ($group) {
        die "group_id=$group_id no longer exists";
    }
    return $group;
}

sub _set_workspace_id {
    my $self = shift;
    $self->clear_workspace();
}

sub _build_workspace {
    my $self = shift;
    require Socialtext::Workspace;      # lazy-load
    my $ws_id     = $self->workspace_id();
    my $workspace = Socialtext::Workspace->new(workspace_id => $ws_id);
    unless ($workspace) {
        die "workspace_id=$ws_id no longer exists";
    }
    return $workspace;
}

sub _set_role_id {
    my $self = shift;
    $self->clear_role();
}

sub _build_role {
    my $self = shift;
    require Socialtext::Role;           # lazy-load
    my $role_id = $self->role_id();
    my $role    = Socialtext::Role->new(role_id => $role_id);
    unless ($role) {
        die "role_id=$role_id no longer exists";
    }
    return $role;
}

sub update {
    my ($self, $proto_gwr) = @_;
    require Socialtext::GroupWorkspaceRoleFactory;
    Socialtext::GroupWorkspaceRoleFactory->Update($self, $proto_gwr);
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Socialtext::GroupWorkspaceRole - A Group's Role in a specific Workspace

=head1 SYNOPSIS

  # create a brand new GWR
  $gwr = Socialtext::GroupWorkspaceRoleFactory->Create( {
      group_id     => $group_id,
      workspace_id => $workspace_id,
      role_id      => $role_id,
  } );

  # update an existing GWR
  $gwr->update( { role_id => $new_role_id } );

=head1 DESCRIPTION

C<Socialtext::GroupWorkspaceRole> provides methods for dealing with the data
in the C<group_workspace_role> table, representing the Role that a Group may
have in a given Workspace.  Each object represents a I<single> row from the
table.

You will commonly see this object referred to as a "GWR" (yes, its a "gwar").

=head1 METHODS

=over

=item B<$gwr-E<gt>group_id()>

The Group Id.

=item B<$gwr-E<gt>group()>

A C<Socialtext::Group> object.

=item B<$gwr-E<gt>workspace_id()>

The Workspace Id.

=item B<$gwr-E<gt>workspace()>

A C<Socialtext::Workspace> object.

=item B<$gwr-E<gt>role_id()>

The Role Id.

=item B<$gwr-E<gt>role()>

A C<Socialtext::Role> object.

=item B<$gwr-E<gt>update(\%proto_gwr)>

Updates the GWR based on the information in the provided C<\%proto_gwr>
hash-ref.

This is simply a helper method which calls
C<Socialtext::GroupWorkspaceRoleFactory->Update($gwr,\%proto_gwr)>

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
