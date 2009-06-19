package Socialtext::JobCreator;
# @COPYRIGHT@
use MooseX::Singleton;
use Socialtext::TheSchwartz;
use Carp qw/croak/;
use Socialtext::Log qw/st_log/;
use namespace::clean -except => 'meta';

has '_client' => (
    is => 'ro', isa => 'Socialtext::TheSchwartz',
    lazy_build => 1,
    handles => qr/(?:list|find|get_server_time|func|move_jobs_by|cancel_job)/,
);

sub _build__client { Socialtext::TheSchwartz->new() }

sub insert {
    my $self = shift;
    my $job_class = shift;
    croak 'Job Class is required' unless $job_class;
    my $args = (@_==1) ? shift : {@_};
    $args->{job} ||= {};
    if ($job_class =~ /::Upgrade::/) {
        $args->{job}{priority} ||= -64;
    }
    return $self->_client->insert($job_class => $args);
}

sub index_attachment {
    my $self = shift;
    my $attachment = shift;
    my $search_config = shift;

    return if ($attachment->page_id eq 'untitled_page');
    return if ($attachment->loaded && $attachment->temporary);

    return $self->insert(
        'Socialtext::Job::AttachmentIndex' => {
            workspace_id => $attachment->hub->current_workspace->workspace_id,
            page_id => $attachment->page_id,
            attach_id => $attachment->id,
            search_config => $search_config,
            job => {priority => 63},
        }
    );
}

sub index_page {
    my $self = shift;
    my $page = shift;
    my $search_config = shift;

    return if $page->id eq 'untitled_page';

    my @job_ids;

    my $main_job_id = $self->insert(
        'Socialtext::Job::PageIndex' => {
            workspace_id => $page->hub->current_workspace->workspace_id,
            page_id => $page->id,
            search_config => $search_config,
            job => {priority => 63},
        }
    );
    push @job_ids, $main_job_id;

    my $attachments = $page->hub->attachments->all( page_id => $page->id );
    foreach my $attachment (@$attachments) {
        next if $attachment->deleted();
        my $job_id = $self->index_attachment($attachment, $search_config);
        push @job_ids, $job_id;
    }

    return @job_ids;
}

sub send_page_notifications {
    my $self = shift;
    my $page = shift;

    my $ws_id = $page->hub->current_workspace->workspace_id;
    my $page_id = $page->id;

    my @job_ids;

    for my $task (qw/WeblogPing EmailNotify WatchlistNotify/) {
        push @job_ids, $self->insert(
            "Socialtext::Job::$task" => {
                workspace_id => $ws_id,
                page_id => $page_id,
                modified_time => $page->modified_time,
                job => { uniqkey => "$ws_id-$page_id" },
            }
        );
    }
    return @job_ids;
}

__PACKAGE__->meta->make_immutable;
1;
