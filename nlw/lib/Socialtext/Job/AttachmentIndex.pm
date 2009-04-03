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
    $indexer->index_attachment( $args->{page_id}, $args->{attach_id} );

    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;
