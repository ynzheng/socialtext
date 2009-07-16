package Socialtext::Workspace::Roles;
# @COPYRIGHT@

use strict;
use warnings;
use Socialtext::MultiCursor;
use Socialtext::SQL qw(:exec);
use Socialtext::User;

###############################################################################
# Common SQL UNION used to get the UserIds of those Users that have a
# relationship with a Workspace.
#
# *REQUIRES* that you pass in "workspace_id" as a binding, *twice*.
our $SQL_UNION_UWR_GWR = qq{
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
};

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
         WHERE user_id IN ( $SQL_UNION_UWR_GWR )
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

###############################################################################
# Get the Count of Users that have a Role in a given Workspace (either
# directly as an UWR, or indirectly as an UGR+GWR).
sub CountUsersByWorkspaceId {
    my $class = shift;
    my %p     = @_;
    my $ws_id = $p{workspace_id};

    my $sql = qq{
        SELECT COUNT(user_id)
          FROM users
         WHERE user_id IN ( $SQL_UNION_UWR_GWR )
    };

    my $count = sql_singlevalue($sql, $ws_id, $ws_id);
    return $count;
}

###############################################################################
# Check to see if a User has a specific Role in the Workspace (either directly
# as an UWR, or indirectly as an UGR+GWR)
sub UserHasRoleInWorkspace {
    my $class = shift;
    my %p     = @_;
    my $user  = $p{user};
    my $role  = $p{role};
    my $ws    = $p{workspace};

    my $user_id = $user->user_id();
    my $role_id = $role->role_id();
    my $ws_id   = $ws->workspace_id();

    my $sql = qq{
        SELECT 1
          FROM users
         WHERE users.user_id = ?
           AND (
                    ( EXISTS (
                        SELECT user_id
                          FROM "UserWorkspaceRole" AS uwr
                         WHERE uwr.user_id = users.user_id
                           AND uwr.role_id = ?
                    ) )
                    OR
                    ( EXISTS (
                        SELECT gwr.group_id
                          FROM group_workspace_role AS gwr
                         WHERE gwr.role_id = ?
                           AND gwr.group_id IN (
                                  SELECT ugr.group_id
                                    FROM user_group_role AS ugr
                                   WHERE ugr.user_id = ?
                             )
                    ) )
               )
    };
    my $is_ok = sql_singlevalue(
        $sql, $user_id,
        $role_id,
        ($role_id, $user_id)
    );
    return $is_ok;
}

###############################################################################
# Get the list of Roles that this User has in the given Workspace (either
# directly as UWRs, or indirectly as UGR+GWRs)
sub RolesForUserInWorkspace {
    my $class = shift;
    my %p     = @_;
    my $user  = $p{user};
    my $ws    = $p{workspace};

    my $user_id = $user->user_id();
    my $ws_id   = $ws->workspace_id();

    my $sql = qq{
        SELECT DISTINCT(role_id)
          FROM (
                ( SELECT uwr.role_id
                    FROM "UserWorkspaceRole" AS uwr
                   WHERE uwr.user_id = ?
                     AND uwr.workspace_id = ?
                )
                UNION
                ( SELECT gwr.role_id
                    FROM group_workspace_role AS gwr
                    JOIN user_group_role ugr USING (group_id)
                   WHERE ugr.user_id = ?
                     AND gwr.workspace_id = ?
                )
          ) AS all_his_roles
    };
    my $sth = sql_execute(
        $sql,
        ($user_id, $ws_id),
        ($user_id, $ws_id),
    );

    # turn the results into a list of Roles
    my @all_roles =
        map  { Socialtext::Role->new(role_id => $_->[0]) }
        @{ $sth->fetchall_arrayref() };

    # sort it from highest->lowest effectiveness
    my @sorted =
        reverse Socialtext::Role->SortByEffectiveness(roles => \@all_roles);

    return wantarray ? @sorted : shift @sorted;
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

  # Get Count of Users that have _some_ Role in a WS
  $count = Socialtext::Workspace::Roles->CountUsersByWorkspaceId(
    workspace_id => $ws_id
  );

  # Most effective Role that User has in Workspace
  $role = Socialtext::Workspace::Roles->RolesForUserInWorkspace(
    user      => $user,
    workspace => $workspace,
  );

  # List of all Roles that User has in Workspace
  @roles = Socialtext::Workspace::Roles->RolesForUserInWorkspace(
    user      => $user,
    workspace => $workspace,
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

=item B<Socialtext::Workspace::Roles-E<gt>CountUsersByWorkspaceId(workspace_id =E<gt> $ws_id)>

Returns the count of Users that have a Role in the Workspace represented by
the given C<workspace_id>.

This method has been optimized so that it doesn't have to fetch B<all> of the
Users from the DB in order to count them up; we just issue the query and take
the count of the results.

=item B<Socialtext::Workspace::Roles-E<gt>UserHasRoleInWorkspace(PARAMS)>

Checks to see if a given User has a given Role in a given Workspace.  Returns
true if it does, false otherwise.

C<PARAMS> must include:

=over

=item user

User object

=item role

Role object

=item workspace

Workspace object

=back

=item B<Socialtext::Workspace::Roles-E<gt>RolesForUserInWorkspace(PARAMS)>

Returns the Roles that the User has in the given Workspace.

In a I<LIST> context, this is the complete list of Roles that the User has in
the Workspace (either explicit, or via Group membership).  List is ordered
from "highest effectiveness to lowest effectiveness", according to the rules
outlined in L<Socialtext::Role>.

In a I<SCALAR> context, this method returns the highest effective Role that
the User has in the Workspace.

C<PARAMS> must include:

=over

=item user

User object

=item workspace

Workspace object

=back

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
