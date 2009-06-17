package Socialtext::Job::EmailNotify;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

sub _should_run_on_page {
    my $self = shift;
    return $self->workspace->email_notify_is_enabled;
}

sub _user_job_class {
    return "Socialtext::Job::EmailNotifyUser";
}

sub _freq_for_user {
    my $self = shift;
    my $user = shift;
    my $prefs = $self->hub->preferences->new_for_user($user->email_address);
    return $prefs->{notify_frequency}->value;
}
sub _get_applicable_users {
    my $self = shift;
    return $self->workspace->users;
}

sub do_work {
    my $self = shift;
    my $page = $self->page or return;
    my $ws = $self->workspace or return;
    my $hub = $self->hub;

    my $t = $self->arg->{modified_time};
    die "no modified_time supplied" unless defined $t;

    my $ws_id = $ws->workspace_id;

    return $self->completed unless $self->workspace->email_notify_is_enabled;

    return $self->completed if $page->is_system_page;
    local $Socialtext::Page::REFERENCE_TIME = $t;
    return $self->completed unless $page->is_recently_modified;

    $hub->log->info( "Sending recent changes notifications from ".$ws->name );
 
    my @jobs;
    my $users = $self->_get_applicable_users();
    my $job_class = $self->_user_job_class;
    while (my $user = $users->next) {
        my $user_id = $user->user_id;
        $hub->current_user($user);
        my $freq = $self->_freq_for_user($user);
        next unless $freq;

        my $after = $t + $freq*60;
        my $job = TheSchwartz::Moosified::Job->new(
            funcname => $job_class,
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
    $hub->log->info("Creating " . scalar(@jobs) . " new $job_class jobs");

    $self->job->client->insert($_) for @jobs;
    $self->completed;
}

__PACKAGE__->meta->make_immutable;
1;
