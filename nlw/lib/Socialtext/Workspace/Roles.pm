package Socialtext::Workspace::Roles;
# @COPYRIGHT@

use strict;
use warnings;
use Socialtext::MultiCursor;
use Socialtext::SQL qw(:exec);
use Socialtext::User;

###############################################################################
# Get a MultiCursor of the Users that have a Role in a given Workspace (either
# directly as an UWR, or indirectly as an UGR+GWR).
#
# The list of Users is de-duped; if a User has multiple Roles in the Workspace
# they only appear _once_ in the resulting MultiCursor.
sub UsersByWorkspaceId {
    my $class = shift;
    my %p     = @_;
    my $ws_id = $p{workspace_id};

    my $sql = qq{
        SELECT user_id, driver_username
          FROM users
         WHERE user_id IN (
                    (   SELECT user_id
                          FROM users
                          JOIN "UserWorkspaceRole" uwr USING (user_id)
                         WHERE uwr.workspace_id = ?
                    )
                    UNION
                    (   SELECT user_id
                          FROM users
                          JOIN user_group_role ugr USING (user_id)
                          JOIN group_workspace_role gwr USING (group_id)
                          WHERE gwr.workspace_id = ?
                    )
                )
         ORDER BY driver_username
    };

    my $sth = sql_execute($sql, $ws_id, $ws_id);
    return Socialtext::MultiCursor->new(
        iterables => [ $sth->fetchall_arrayref ],
        apply => sub {
            my $row = shift;
            return Socialtext::User->new(user_id => $row->[0]);
        },
    );
}

1;

=head1 NAME

Socialtext::Workspace::Roles - User/Workspace Role helper methods

=head1 SYNOPSIS

  use Socialtext::Workspace::Roles;

  # Get Users that have _some_ Role in a WS
  $cursor = Socialtext::Workspace::Roles->UsersByWorkspaceId(
    workspace_id => $ws_id
  );

=head1 DESCRIPTION

C<Socialtext::Workspace::Roles> gathers together a series of helper methods to
help navigate the various types of relationships between "Users" and
"Workspaces" under one hood.

Some of these relationships are direct (User->Workspace), while others are
indirect (User->Group->Workspace).  The methods in this module aim to help
flatten the relationships so you don't have to care B<how> the User has the
Role in the given Workspace, only that he has it.

=head1 METHODS

=over

=item B<Socialtext::Workspace::Roles-E<gt>UsersByWorkspaceId(workspace_id =E<gt> $ws_id)>

Returns a C<Socialtext::MultiCursor> containing all of the Users that have a
Role in the Workspace represented by the given C<workspace_id>.

The list of Users returned is I<already> de-duped (so any User appears once
and only once in the list), and is ordered by Username.

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut