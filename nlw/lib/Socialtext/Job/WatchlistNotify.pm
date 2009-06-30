package Socialtext::Job::WatchlistNotify;
# @COPYRIGHT@
use Moose;
use Socialtext::Watchlist;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job::EmailNotify';

override '_user_job_class' => sub {
    return "Socialtext::Job::WatchlistNotifyUser";
};

override '_freq_for_user' => sub {
    my $self = shift;
    my $user = shift;
    my $prefs = $self->hub->preferences->new_for_user($user->email_address);
    return $prefs->{watchlist_notify_frequency}->value * 60;
};


override '_get_applicable_users' => sub {
    my $self = shift;

    # find the users that have this page watched.
    return Socialtext::Watchlist->Users_watching_page(
        $self->workspace->workspace_id, $self->page->id,
    );
};

__PACKAGE__->meta->make_immutable;
1;
