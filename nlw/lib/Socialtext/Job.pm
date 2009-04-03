package Socialtext::Job;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';

extends 'TheSchwartz::Moosified::Worker';

has job => (
    is => 'rw', isa => 'TheSchwartz::Moosified::Job',
    handles => [qw(
        arg
        permanent_failure
        failed
        completed
    )],
);

has workspace => (
    is => 'ro', isa => 'Maybe[Socialtext::Workspace]',
    lazy_build => 1,
);

has hub => (
    is => 'ro', isa => 'Maybe[Socialtext::Hub]',
    lazy_build => 1,
);

has indexer => (
    is => 'ro', isa => 'Maybe[Socialtext::Search::Indexer]',
    lazy_build => 1,
);

sub work {
    my $class = shift;
    my $job = shift;
    my $self = $class->new(
        job => $job
    );
    return $self->do_work();
}

sub _build_workspace {
    my $self = shift;
    my $ws_id = $self->arg->{workspace_id} || 0;

    require Socialtext::Workspace;

    if ($ws_id) {
        return Socialtext::Workspace->new(workspace_id => $ws_id);
    }
    else {
        return Socialtext::NoWorkspace->new();
    }
}

sub _build_hub {
    my $self = shift;
    my $ws = $self->workspace or return;

    require Socialtext;
    require Socialtext::User;

    my $main = Socialtext->new();
    $main->load_hub(
        current_workspace => $ws,
        current_user      => Socialtext::User->SystemUser,
    );
    $main->hub()->registry()->load();

    return $main->hub;
}

sub _build_indexer {
    my $self = shift;

    my $ws = $self->workspace or return;

    require Socialtext::Search::AbstractFactory;

    my $indexer = eval {
        Socialtext::Search::AbstractFactory->GetFactory->create_indexer(
            $self->workspace->name,
            config_type => ($self->arg->{search_config} || 'live')
        );
    };
    unless($indexer) {
        $self->permanent_failure("Couldn't create a indexer");
        die "Couldn't create an indexer: $@";
    }
    return $indexer;
}

__PACKAGE__->meta->make_immutable;
1;
