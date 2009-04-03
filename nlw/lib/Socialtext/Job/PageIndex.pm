package Socialtext::Job::PageIndex;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

sub do_work {
    my $self = shift;

    my $hub = $self->hub or return;
    my $indexer = $self->indexer or return;

    my $page = $hub->pages->new_page($self->arg->{page_id});

    $indexer->index_page($page->id);

    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;
