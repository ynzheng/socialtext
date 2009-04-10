package Socialtext::Job::PageIndex;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

sub do_work {
    my $self    = shift;
    my $page    = $self->page or return;
    my $indexer = $self->indexer or return;

    $indexer->index_page($page->id);

    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;
