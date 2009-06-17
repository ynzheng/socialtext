package Socialtext::Job::EmailNotify;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

sub do_work {
    my $self = shift;
    my $page = $self->page or return;
    my $ws = $self->workspace or return;
    my $hub = $self->hub;

    my $t = $self->arg->{modified_time};
    die "no modified_time supplied" unless defined $t;

    my $ws_id = $ws->workspace_id;

    return $self->completed unless $ws->email_notify_is_enabled;
    return $self->completed if $page->is_system_page;
    local $Socialtext::Page::REFERENCE_TIME = $t;
    return $self->completed unless $page->is_recently_modified;

    $hub->log->info( "Sending recent changes notifications from ".$ws->name );
 
    my @jobs;
    my $users = $ws->users;
    while (my $user = $users->next) {
        my $user_id = $user->user_id;
        $hub->current_user($user);
        my $prefs = $self->hub->preferences->new_for_user($user->email_address);
        my $freq = $prefs->{notify_frequency}->value;
        next unless $freq;

        my $after = $t + $freq*60;
        my $job = TheSchwartz::Moosified::Job->new(
            funcname => 'Socialtext::Job::EmailNotifyUser',
            priority => -32767,
            run_after => $after,
            uniqkey => "$ws_id-$user_id",
            arg => {
                user_id => $user_id,
                workspace_id => $ws_id,
                pages_after => $t,
            }
        );
        push @jobs, $job if $job;
    }
    $hub->log->info("Creating " . scalar(@jobs) . " new email notify jobs");

    $self->job->client->insert($_) for @jobs;
    $self->completed;
}

__PACKAGE__->meta->make_immutable;
1;
