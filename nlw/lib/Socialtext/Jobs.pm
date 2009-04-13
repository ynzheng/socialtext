package Socialtext::Jobs;
# @COPYRIGHT@
use MooseX::Singleton;
use Socialtext::TheSchwartz;
use Socialtext::SQL qw/sql_execute/;
use Module::Pluggable search_path => 'Socialtext::Job',
    sub_name => 'job_types', require => 0;
use Memoize;
use Carp qw/croak/;
use POSIX qw/strftime/;
use namespace::clean -except => [qw(meta job_types)];

has '_client' => (
    is => 'ro', isa => 'Socialtext::TheSchwartz',
    lazy_build => 1,
    handles => qr/^.+$/,
);

around 'insert' => sub {
    croak 'Use Socialtext::JobCreator->insert to create jobs'
};

sub _build__client { Socialtext::TheSchwartz->new() }

memoize 'job_types';

sub load_all_jobs {
    my $self = shift;
    for my $job_type ($self->job_types) {
        eval "require $job_type";
        croak $@ if $@;
    }
}

sub can_do_all {
    my $self = shift;
    $self->load_all_jobs();
    $self->can_do($_) for $self->job_types;
}

sub clear_jobs { sql_execute('DELETE FROM job') }

sub job_to_string {
    my $class = shift;
    my $job = shift;
    my $opts = shift || {};

    my $string = strftime "%Y-%m-%d.%H:%M:%S", localtime($job->insert_time);

    $string .= " id=" . $job->jobid;
    (my $shortname = $job->funcname) =~ s/^Socialtext::Job:://;
    $string .= ";type=$shortname";

    return $string unless ref($job->arg) eq 'HASH';

    if (my $ws_id = $job->arg->{workspace_id}) {
        $opts->{ws_names} ||= {};
        eval {
            $opts->{ws_names}{$ws_id} ||=
                Socialtext::Workspace->new( workspace_id => $ws_id )->name;
            $string .= ";ws=$opts->{ws_names}{$ws_id}";
        };
        if ($@) {
            $string .= ";ws=$ws_id";
        }
    }
    $string .= ";page=".$job->arg->{page_id}
        if $job->arg->{page_id};

    if ($shortname eq 'Cmd') {
        $string .= ";cmd=".$job->arg->{cmd};
        $string .= ";args=".join(',',@{$job->arg->{args} || []});
    }

    if ($job->run_after > time) {
        my $when = strftime("%Y-%m-%d.%H:%M:%S", localtime($job->run_after));
        $string .= " (delayed until $when)";
    }

    $string .= " (*)" if $job->grabbed_until;

    return $string unless wantarray;
    return ($string, $shortname);
}

__PACKAGE__->meta->make_immutable;
1;
