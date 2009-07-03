package Socialtext::Events::Stream::Pages;
use Moose;
use MooseX::StrictConstructor;
use Socialtext::SQL qw/:exec/;
use Socialtext::Events::Source::Workspace;
use namespace::clean -except => 'meta';

with 'Socialtext::Events::Stream';

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

    # TODO: respect a page_workspace_id param (with permission check)

    local $Socialtext::SQL::PROFILE_SQL = 1;
    my $sth = sql_execute(q{
        SELECT workspace_id FROM "UserWorkspaceRole" WHERE user_id = $1

        UNION

        SELECT workspace_id
        FROM "WorkspaceRolePermission" wrp
        JOIN "Role" r USING (role_id)
        JOIN "Permission" p USING (permission_id)
        WHERE
            -- workspace vis
            r.name = 'guest' AND p.name = 'read'
    }, $self->viewer_id);

    my $rows = $sth->fetchall_arrayref;
    my @ids = map {$_->[0]} @$rows;

    return \@ids;
}

sub _build_sources {
    my $self = shift;

    my @sources;
    for my $workspace_id (@{ $self->workspace_ids }) {
        push @sources, $self->construct_source(
            'Socialtext::Events::Source::Workspace',
            workspace_id => $workspace_id
        );
    }

    return \@sources;
}

__PACKAGE__->meta->make_immutable;
1;
