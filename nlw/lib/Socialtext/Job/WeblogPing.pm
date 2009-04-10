package Socialtext::Job::WeblogPing;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';
use Socialtext::WeblogUpdates;

extends 'Socialtext::Job';

sub do_work {
    my $self = shift;
    my $page = $self->page or return;

    Socialtext::WeblogUpdates->new(hub => $page->hub)->send_ping($page);

    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;
