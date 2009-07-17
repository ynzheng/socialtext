package Socialtext::Events::Stream::HasWorkspaces;
use Moose::Role;
use Socialtext::SQL qw/:exec/;
use List::Util qw/first/;
use namespace::clean -except => 'meta';

requires 'assemble';

has 'workspace_ids' => (
    is => 'rw', isa => 'ArrayRef[Int]',
    lazy_build => 1,
);

before 'assemble' => sub {
    my $self = shift;
    $self->workspace_ids; # force builder
    return;
};

sub _build_workspace_ids {
    my $self = shift;

    # TODO: respect group membership
    my $sth = sql_execute(q{
        SELECT workspace_id FROM "UserWorkspaceRole" WHERE user_id = $1

        UNION

        SELECT workspace_id
        FROM "WorkspaceRolePermission" wrp
        JOIN "Role" r USING (role_id)
        JOIN "Permission" p USING (permission_id)
        WHERE r.name = 'guest' AND p.name = 'read'
    }, $self->viewer_id);

    my $rows = $sth->fetchall_arrayref;
    my @ids = map {$_->[0]} @$rows;

    if ($self->filter->has_page_workspace_id) {
        my $wses = $self->filter->page_workspace_id;
        if (!defined $wses) {
            # just use visible workspaces
        }
        elsif (ref($wses)) {
            my %wanted = map { $_ => 1 } @$wses;
            @ids = grep { $wanted{$_} } @ids;
        }
        else {
            @ids = first {$wses==$_} @ids;
        }
    }

    return [grep {defined} @ids];
}

1;
