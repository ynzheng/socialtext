package Socialtext::User::Find::Workspace;
# @COPYRIGHT@
use Moose;
use Socialtext::SQL qw/get_dbh sql_execute/;
use Socialtext::String;
use Socialtext::User;
use namespace::clean -except => 'meta';

extends 'Socialtext::User::Find';

has workspace => (is => 'rw', isa => 'Socialtext::Workspace', required => 1);

sub get_results {
    my $self = shift;

    my $sql = q{
        SELECT user_id, first_name, last_name, email_address, driver_username,
               "Role".name as role_name,
               "Role".name = 'workspace_admin' AS is_workspace_admin
        FROM users
        JOIN "UserWorkspaceRole" USING(user_id)
        JOIN "Role" USING(role_id)
        WHERE workspace_id = $3
        AND (
            lower(first_name) LIKE $1 OR
            lower(last_name) LIKE $1 OR
            lower(email_address) LIKE $1 OR
            lower(driver_username) LIKE $1
        )
        AND EXISTS (
            SELECT 1
            FROM account_user viewer
            JOIN account_user found USING (account_id)
            WHERE viewer.user_id = $2 AND found.user_id = users.user_id
        )
        ORDER BY last_name ASC, first_name ASC
        LIMIT $4 OFFSET $5
    };

    #local $Socialtext::SQL::PROFILE_SQL = 1;
    my $sth = sql_execute($sql, 
        $self->filter, $self->viewer->user_id, $self->workspace->workspace_id,
        $self->limit, $self->offset,
    );

    return $sth->fetchall_arrayref({}) || [];
}

__PACKAGE__->meta->make_immutable;
1;
