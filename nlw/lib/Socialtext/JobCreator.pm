package Socialtext::JobCreator;
# @COPYRIGHT@
use MooseX::Singleton;
use Socialtext::TheSchwartz;
use Carp qw/croak/;
use namespace::clean -except => 'meta';

has '_client' => (
    is => 'ro', isa => 'Socialtext::TheSchwartz',
    lazy_build => 1,
    handles => qr/(?:list|find|get_server_time|func)/,
);

sub _build__client { Socialtext::TheSchwartz->new(verbose => 1) }

sub insert {
    my $self = shift;
    my $job_class = shift;
    croak 'Job Class is required' unless $job_class;
    my $args = (@_==1) ? shift : {@_};
    return $self->_client->insert($job_class => $args);
}

sub index_attachment {
    my $self = shift;
    my $attachment = shift;
    my $search_config = shift;

    return $self->index(
        'Socialtext::Job::AttachmentIndex' => {
            workspace_id => $attachment->hub->current_workspace->workspace_id,
            page_id => $attachment->page_id,
            attach_id => $attachment->id,
            search_config => $search_config,
        }
    );
}

sub index_page {
    my $self = shift;
    my $page = shift;
    my $search_config = shift;

    my @job_ids;

    $self->_log_page_action($page);

    my $main_job_id = $self->index(
        'Socialtext::Job::PageIndex' => {
            workspace_id => $page->hub->current_workspace->workspace_id,
            page_id => $page->id,
            search_config => $search_config,
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

sub _log_page_action {
    my $self = shift;
    my $page = shift;

    my $action = $page->hub->action || '';
    my $clobber = eval { $page->hub->rest->query->param('clobber') };

    return if $clobber
        || $action eq 'submit_comment'
        || $action eq 'attachments_upload';

    if ($action eq 'edit_content' || $action eq 'rename_page') {
         return unless ($page->restored || $page->revision_count == 1);
    }

    my $log_action = ($action eq 'delete_page') ? 'DELETE' : 'CREATE';
    my $ws         = $page->hub->current_workspace;
    my $user       = $page->hub->current_user;

    st_log()->info("$log_action,PAGE,"
                   . 'workspace:' . $ws->name . '(' . $ws->workspace_id . '),'
                   . 'page:' . $page->id . ','
                   . 'user:' . $user->username . '(' . $user->user_id . '),'
                   . '[NA]'
    );
}

__PACKAGE__->meta->make_immutable;
1;
