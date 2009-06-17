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

has user => (
    is => 'ro', isa => 'Maybe[Socialtext::User]',
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

    return Socialtext::NoWorkspace->new() unless $ws_id;

    my $ws = Socialtext::Workspace->new(workspace_id => $ws_id);
    return $ws if $ws;

    my $msg = "workspace id=$ws_id no longer exists";
    $self->permanent_failure($msg);
    die $msg;
}

sub _build_hub {
    my $self = shift;
    my $ws = $self->workspace or return;
    my $user = $self->user || Socialtext::User->SystemUser;

    require Socialtext;
    require Socialtext::User;

    my $main = Socialtext->new();
    $main->load_hub(
        current_workspace => $ws,
        current_user      => $user,
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
            $ws->name,
            config_type => ($self->arg->{search_config} || 'live')
        );
    };
    unless ($indexer) {
        my $err = $@ || 'unknown error';
        my $msg = "Couldn't create an indexer: $@";
        $self->permanent_failure($msg);
        die $msg;
    }
    return $indexer;
}

sub _build_page {
    my $self = shift;
    my $hub = $self->hub or return;
    my $page_id = $self->arg->{page_id};
    return unless $page_id;

    my $page = eval { $hub->pages->new_page($self->arg->{page_id}) };
    return $page if ($page && $page->exists); # checks filesystem

    my $msg = "Couldn't load page id=$page_id from the '" . 
        $hub->current_workspace->name .
        "' workspace: $@";
    $self->failed($msg);
    die $msg;
}

sub _build_user {
    my $self = shift;
    my $user_id = $self->arg->{user_id};
    return unless $user_id;
    return Socialtext::User->new(user_id => $user_id);
}

__PACKAGE__->meta->make_immutable;
1;
