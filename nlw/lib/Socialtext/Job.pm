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

has page => (
    is => 'ro', isa => 'Maybe[Socialtext::Page]',
    lazy_build => 1,
);

# These are called as class methods:
override 'keep_exit_status_for' => sub {3600};
override 'grab_for'             => sub {3600};
override 'retry_delay'          => sub {0};
override 'max_retries'          => sub {0};

sub work {
    my $class = shift;
    my $job = shift;
    eval {
        my $self = $class->new(job => $job);
        $self->do_work();
    };
    if ($@) {
        # make sure to record a result of 255
        $job->failed($@, 255);
        die $@;
    }
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

sub _build_page {
    my $self = shift;
    my $hub = $self->hub or return;
    return $hub->pages->new_page($self->arg->{page_id});
}

__PACKAGE__->meta->make_immutable;
1;
