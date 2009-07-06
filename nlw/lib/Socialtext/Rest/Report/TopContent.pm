package Socialtext::Rest::Report::TopContent;
# @COPYRIGHT@
use Moose;
use Socialtext::JSON qw/encode_json/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::ReportAdapter';

=head1 NAME

Socialtext::Rest::Report::TopContent - top content

=head1 SYNOPSIS

  GET /data/reports/top_content/now/-1week

=head1 DESCRIPTION

Shows the top viewed/edited/watched/emailed pages
in a workspace or account.

=cut

override 'GET_json' => sub {
    my $self = shift;
    my $user = $self->rest->user;

    my $report = eval { $self->adapter->_build_report(
        'TopContentByPage', {
            start_time => $self->start,
            duration   => $self->duration,
            type       => 'raw',
        }, $user,
    ) };
    return $self->error(400, 'Bad request', $@) if $@;
    my $authorized = eval { $report->is_viewable_by($user) };
    warn $@ if $@;
    return $self->not_authorized unless $authorized;

    my @pages;
    eval { 
        my $data = $report->_data;
        # Clean up the data
        for my $row (@$data) {
            my ($ws_name, $page_id, $count) = @$row;

            my $wksp = Socialtext::Workspace->new( name => $ws_name );
            $page_id ||= $wksp->title;

            $self->hub->current_workspace($wksp);

            my $page  = eval { $self->hub->pages->new_from_uri($page_id) };
            if ($@) { warn $@; next }

            push @pages, {
                title          => $page->title,
                uri            => $page->full_uri,
                is_spreadsheet => $page->is_spreadsheet,
                ws_name        => $wksp->name,
                ws_title       => $wksp->title,
                ws_uri         => $wksp->uri,
                count          => $count,
            };
        }
    };
    return $self->error(400, 'Bad request', $@) if $@;

    $self->rest->header(-type => 'application/json');
    my $json;
    eval {
        $json = encode_json({
            rows => \@pages,
            meta  => {
                account   => $self->_account_data( $report ),
                workspace => $self->_workspace_data( $report ),
            },
        });
    };
    return $self->error(400, 'Bad request', $@) if $@;
    return $json;
};

sub _account_data {
    my $self    = shift;
    my $report  = shift;

    # it is required that we either have a valid workspace or a valid
    # account.
    my $account = $report->account;
    if ($report->workspace) {
        $account ||= $report->workspace->account();
    }
    die "Could not find an account!" unless $account;

    return { name => $account->name };
}

sub _workspace_data {
    my $self      = shift;
    my $report    = shift;
    my $workspace = $report->workspace;

    return {} unless $workspace;

    return {
        title => $workspace->title,
        uri   => $workspace->uri,
    }
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
