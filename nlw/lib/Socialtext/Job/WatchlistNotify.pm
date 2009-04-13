package Socialtext::Job::WatchlistNotify;
# @COPYRIGHT@
use Moose;
use Socialtext::WeblogUpdates;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

sub do_work {
    my $self = shift;
    my $page = $self->page or return;

    $page->hub->watchlist->maybe_send_notifications( $page->id );

    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;
