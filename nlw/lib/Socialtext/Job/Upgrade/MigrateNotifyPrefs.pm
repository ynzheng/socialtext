package Socialtext::Job::Upgrade::MigrateNotifyPrefs;
# @COPYRIGHT@
use Moose;
use Socialtext::Paths;
use Socialtext::Workspace::Importer;
use Socialtext::JobCreator;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

=head1 NAME

Socialtext::Job::Upgrade::MigrateNotifyPrefs - migrate email & watchlist notify state

=head1 SYNOPSIS

  Create a job for each workspace

=head1 DESCRIPTION

Migrates data from disk into the new schwartz-based notifier system.  Deletes
data off disk after it is migrated.

=cut

use constant WINDOW_LIMIT => 14 * 86400; # 14 days

sub do_work {
    my $self = shift;
    my $ws   = $self->workspace;

    # TODO: still clean up files if notify is disabled
    return $self->completed unless $ws->email_notify_is_enabled;

    return $self->completed unless $ws->real;

    my $path = Socialtext::Paths::user_directory($ws->name);
    my $plugin_dir = Socialtext::Paths::plugin_directory($ws->name);
    for my $notify_dir (qw/email_notify watchlist/) {
        my $pref_key = ($notify_dir eq 'watchlist' ? 'watchlist_' : '')
                       . 'notify_frequency';

        my @files = glob("$path/*/$notify_dir/email_timestamp");
        for my $f (@files) {
            (my $email = $f) =~ s#^$path/([^/]+)/.+$#$1#;
            my $user = Socialtext::User->new(email_address => $email);

            my $last_email = (stat($f))[9];
            $self->_schedule_notify_job($user, $pref_key, $last_email)
                if ($user && $ws->real);

            (my $pref_dir = $f) =~ s#/email_timestamp$##;
            for my $file (glob("$pref_dir/*")) {
                unlink $file or warn "Could not unlink $file: $!";
            }
            rmdir $pref_dir or warn "Could not rmdir $pref_dir: $!";
        }

        my @pref_dirs = glob("$path/*/$notify_dir");
        for my $d (@pref_dirs) {
            if (-d $d) {
                rmdir $d or warn "Could not rmdir $d $!";
            }
            else {
                unlink $d;
            }

            # Try to also delete the user dir, which may now be empty.
            (my $user_dir = $d) =~ s#/$notify_dir$##;
            rmdir $user_dir;
        }

        # last e-mail run time for a workspace
        unlink "$plugin_dir/$notify_dir/last_run_stamp";
        unlink "$plugin_dir/$notify_dir/lock";
        rmdir "$plugin_dir/$notify_dir";
    }
    
    # Clean up these odd '.email_notify' files (legacy timestamps?)
    my @strange_notify_files = glob("$path/*/.email_notify");
    for my $strange_file (@strange_notify_files) {
        next unless -f $strange_file;
        unlink $strange_file;
    }

    $self->completed();
}

sub _schedule_notify_job {
    my $self       = shift;
    my $user       = shift;
    my $pref_key   = shift;
    my $last_email = shift;

    my $ws_id = $self->workspace->workspace_id;
    my $user_id = $user->user_id;

    my $prefs = $self->hub->preferences->new_for_user($user->email_address);
    my $freq = $prefs->{$pref_key}->value;
    return unless $freq;
    $freq *= 60;

    my $now = $self->job->insert_time;

    # if it's more than WINDOW_LIMIT overdue
    my ($run_after, $pages_after);
    my $window_end = $last_email + $freq;
    if (($now - $window_end) > WINDOW_LIMIT) {
        # don't return a ton of results for really old timestamps
        $pages_after = $now - WINDOW_LIMIT;
        $run_after = $now;
    }
    else {
        $pages_after = $last_email;
        $run_after = $last_email + $freq;
    }

    my $job_type = $pref_key eq 'notify_frequency'
                    ? 'Socialtext::Job::EmailNotifyUser'
                    : 'Socialtext::Job::WatchlistNotifyUser';
    my $job = TheSchwartz::Moosified::Job->new(
        funcname => $job_type,
        priority => -64,
        run_after => $run_after,
        uniqkey => "$ws_id-$user_id",
        arg => {
            workspace_id => $ws_id,
            user_id => $user_id,
            pages_after => $pages_after,
        },
    );
    
    $self->job->client->insert($job);
}

__PACKAGE__->meta->make_immutable;
1;
