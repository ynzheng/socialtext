package Socialtext::Events::Stream::Conversations;
use Moose;
use Socialtext::Events::Source::WorkspaceConversations;
use namespace::clean -except => 'meta';

extends 'Socialtext::Events::Stream';
with 'Socialtext::Events::Stream::HasWorkspaces';

after 'add_sources' => sub {
    my $self = shift;
    my $sources = shift;

    for my $workspace_id (@{ $self->workspace_ids }) {
        push @$sources, $self->construct_source(
            'Socialtext::Events::Source::WorkspaceConversations',
            workspace_id => $workspace_id
        );
    }
};

__PACKAGE__->meta->make_immutable;
1;
