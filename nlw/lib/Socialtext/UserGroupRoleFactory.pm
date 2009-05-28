package Socialtext::UserGroupRoleFactory;
# @COPYRIGHT@

use MooseX::Singleton;
use Socialtext::SQL qw/:exec/;
use Socialtext::SQL::Builder qw(:all);
use Socialtext::Role;
use Socialtext::UserGroupRole;
use namespace::clean -except => 'meta';

sub GetUserGroupRole {
    my ($self, %p) = @_;
    my $user_id  = $p{user_id}  || die "no user_id";
    my $group_id = $p{group_id} || die "no group_id";

    # map the attributes to their DB columns
    my $meta = Socialtext::UserGroupRole->meta;
    my $user_id_column  = $meta->get_attribute('user_id')->column_name();
    my $group_id_column = $meta->get_attribute('group_id')->column_name();

    # fetch the UGR from the DB
    my $sql = qq{
        SELECT role_id
          FROM user_group_role
         WHERE $user_id_column = ?
           AND $group_id_column = ?
    };
    my $role_id = sql_singlevalue($sql, $user_id, $group_id);
    return undef unless $role_id;

    # create the UGR object
    return Socialtext::UserGroupRole->new( {
        user_id  => $user_id,
        group_id => $group_id,
        role_id  => $role_id,
    } );
}

sub NewUGRRecord {
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
}

sub Create {
    my ($self, $proto_ugr) = @_;
    $proto_ugr->{role_id} ||= $self->DefaultRoleId();
    $self->NewUGRRecord($proto_ugr);
    return $self->GetUserGroupRole(%{$proto_ugr});
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

=item $factory-E<gt>GetUserGroupRole(PARAMS)

Looks for an existing record in the user_group_role table matching PARAMS and
returns a C<Socialtext::UserGroupRole> representing that row, or undef if it
can't find a match.

PARAMS I<must> be:

=over 8

=item * user_id =E<gt> $user_id

=item * group_id =E<gt> $group_id

=back

=item $factory-E<gt>NewUGRRecord($proto_ugr)

Create a new entry in the user_group_role table, if possible, and return the corresponding C<Socialtext::UserGroupRole> object on success.

C<$proto_ugr> I<must> include the following:

=over 8

=item * user_id =E<gt> $user_id

=item * group_id =E<gt> $group_id

=item * role_id =E<gt> $role_id

=back

=item $factory-E<gt>Create($proto_ugr)

Create a new entry in the user_group_role table, a simplfied wrapper around
C<NewUGRRecord>.

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

=item $factory-E<gt>DefaultRoleId()

Get the ID for the default Role being  used.

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut

