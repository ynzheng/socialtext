package Socialtext::Job::Test;
# @COPYRIGHT@
use Moose;
use Socialtext::Log qw/st_log/;
use Time::HiRes qw/sleep/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

our $Work_count = 0;
our $Retries = 0;
our $Keep_exit_status_for = 3600;
our $Grab_for = 3600;

override 'max_retries' => sub { $ENV{TEST_JOB_RETRIES} || $Retries };
override 'keep_exit_status_for' => sub { $Keep_exit_status_for };
override 'grab_for' => sub { $Grab_for };

sub do_work {
    my $self = shift;
    my $args = $self->arg;

    die "failed!\n" if $args->{fail};

    st_log->debug($args->{message})      if $args->{message};
    sleep $args->{sleep}                 if $args->{sleep};
    st_log->debug($args->{post_message}) if $args->{post_message};

    # exercise the lazy builders
    if ($args->{get_workspace}) {
        my $ws = $self->workspace;
        st_log->debug("Workspace: ".$ws->name);
    }
    if ($args->{get_page}) {
        my $page = $self->page;
        st_log->debug("Page ".$page->title);
    }
    if ($args->{get_indexer}) {
        my $indexer = $self->indexer;
        st_log->debug("Indexer OK");
    }

    $Work_count++;
    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;
