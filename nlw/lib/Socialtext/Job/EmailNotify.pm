package Socialtext::Job::EmailNotify;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';
use Socialtext::WeblogUpdates;

extends 'Socialtext::Job';

sub do_work {
    my $self = shift;
    my $page = $self->page or return;

    $page->hub->email_notify->maybe_send_notifications( $page->id );

    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;
