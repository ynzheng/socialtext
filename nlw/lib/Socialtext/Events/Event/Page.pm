package Socialtext::Events::Event::Page;
# @COPYRIGHT@
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use Socialtext::Model::Pages;
use Socialtext::Workspace;
use namespace::clean -except => 'meta';

extends 'Socialtext::Events::Event';

enum 'PageEventAction' => qw(
    comment
    delete
    duplicate
    edit_cancel
    edit_contention
    edit_save
    edit_start
    lock_page
    rename
    tag_add
    tag_delete
    unlock_page
    view
    watch_add
    watch_delete
);

has '+action' => (isa => 'PageEventAction');
has 'page_workspace_id' => (is => 'ro', isa => 'Int', required => 1);
has 'page_id' => (is => 'ro', isa => 'Str', required => 1);

has 'workspace' => (
    is => 'ro', isa => 'Socialtext::Workspace',
    lazy_build => 1,
);

has 'page' => (
    is => 'ro', isa => 'Socialtext::Model::Page',
    lazy_build => 1,
    handles => {
        page_title => 'title',
        page_name => 'title',
        page_type => 'type',
        workspace_name => 'workspace_name',
        workspace_title => 'workspace_title',
    },
);

sub _build_workspace {
    Socialtext::Workspace->new(workspace_id => $_[0]->page_workspace_id);
}

sub _build_page {
    my $self = shift;

    my $page = Socialtext::Model::Pages->By_id(
        workspace_id => $self->page_workspace_id,
        page_id => $self->page_id,
        do_not_need_tags => 1,
        deleted_ok => 1,
    );
}

# alias
sub workspace_id { $_[0]->page_workspace_id }

sub page_uri {
    my $self = shift;
    return "/data/workspaces/".$self->workspace_name."/pages/".$self->page_id;
}

sub revision_id    { $_[0]->context_hash->{revision_id} }
sub revision_count { $_[0]->context_hash->{revision_count} }

after 'build_hash' => sub {
    my $self = shift;
    my $h = shift;

    $h->{event_class} = 'page';

    my $p = $h->{page} ||= {};
    $p->{id} = $self->page_id;
    $p->{name} = $self->page_name;
    $p->{type} = $self->page_type;
    $p->{workspace_name} = $self->workspace_name;
    $p->{workspace_title} = $self->workspace_title;
    $p->{uri} = $self->page_uri;
};

__PACKAGE__->meta->make_immutable;
1;
