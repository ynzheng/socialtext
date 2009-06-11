package Socialtext::UserGroupRole;
# @COPYRIGHT@

use Moose;
use Socialtext::MooseX::SQL;
use Socialtext::User;
use Socialtext::Group;
use Socialtext::Role;
use namespace::clean -except => 'meta';

has_column 'user_id' => (
    is => 'rw', isa => 'Int',
    writer => '_user_id',
    trigger => \&_set_user_id,
    primary_key => 1,
);

has 'user' => (
    is => 'ro', isa => 'Socialtext::User',
    lazy_build => 1,
);

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

sub _set_user_id {
    my $self = shift;
    $self->clear_user();
}

sub _build_user {
    my $self    = shift;
    my $user_id = $self->user_id();
    my $user    = Socialtext::User->new(user_id => $user_id);
    unless ($user) {
        die "user_id=$user_id no longer exists";
    }
    return $user;
}

sub _set_group_id {
    my $self = shift;
    $self->clear_group();
}

sub _build_group {
    my $self     = shift;
    my $group_id = $self->group_id();
    my $group    = Socialtext::Group->GetGroup(group_id => $group_id);
    unless ($group) {
        die "group_id=$group_id no longer exists";
    }
    return $group;
}

sub _set_role_id {
    my $self = shift;
    $self->clear_role();
}

sub _build_role {
    my $self    = shift;
    my $role_id = $self->role_id();
    my $role    = Socialtext::Role->new(role_id => $role_id);
    unless ($role) {
        die "role_id=$role_id no longer exists";
    }
    return $role;
}

sub update {
    my ($self, $proto_ugr) = @_;
    require Socialtext::UserGroupRoleFactory;
    Socialtext::UserGroupRoleFactory->Update($self, $proto_ugr);
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Socialtext::UserGroupRole - A User's Role in a specific Group

=head1 SYNOPSIS

  # create a brand new UGR
  $ugr = Socialtext::UserGroupRoleFactory->Create( {
      user_id   => $user_id,
      group_id  => $group_id,
      role_id   => $role_id,
  } );

  # update an existing UGR
  $ugr->update( { role_id => $new_role_id } );

=head1 DESCRIPTION

C<Socialtext::UserGroupRole> provides methods for dealing with the data in the
C<user_group_role> table, representing the Role that a User may have in a
given Group.  Each object represents a I<single> row from the table.

You will commonly see this object referred to as an "UGR", which rhymes with
"booger" (but without the B).

=head1 METHODS

=over

=item B<$ugr-E<gt>user_id()>

The User Id.

=item B<$ugr-E<gt>user()>

A C<Socialtext::User> object.

=item B<$ugr-E<gt>group_id()>

The Group Id.

=item B<$ugr-E<gt>group()>

A C<Socialtext::Group> object.

=item B<$ugr-E<gt>role_id()>

The Role Id.

=item B<$ugr-E<gt>role()>

A C<Socialtext::Role> object.

=item B<$ugr-E<gt>update(\%proto_ugr)>

Updates the UGR based on the information in the provided C<\%proto_ugr>
hash-ref.

This is simply a helper method which calls
C<Socialtext::UserGroupRoleFactory->Update($ugr,\%proto_ugr)>

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
