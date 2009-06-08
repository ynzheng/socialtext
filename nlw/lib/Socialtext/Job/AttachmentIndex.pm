package Socialtext::Job::AttachmentIndex;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

sub do_work {
    my $self = shift;
    my $args = $self->arg;
    my $indexer = $self->indexer
        or die "can't create indexer";

    my $page = eval { $self->page };
    # this should be done in the builder for ->page, but just in case:
    unless ($page && $page->exists) {
        $self->permanent_failure(
            "No page $args->{page_id} in workspace $args->{workspace_id}\n"
        );
        return;
    }

    $indexer->index_attachment( $args->{page_id}, $args->{attach_id} );

    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;
