package Socialtext::Rest::Report::TopPeople;
# @COPYRIGHT@
use Moose;
use Socialtext::JSON qw/encode_json/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::ReportAdapter';

=head1 NAME

Socialtext::Rest::Report::TopPeople - top peopl

=head1 SYNOPSIS

  GET /data/reports/top_people/now/-1week

=head1 DESCRIPTION

Shows the top viewers/editors/watchers/emailers/signalers
in a workspace or account.

=cut

override 'GET_json' => sub {
    my $self = shift;
    my $user = $self->rest->user;

    my $report = eval { $self->adapter->_build_report(
        'TopContentByUser', {
            start_time => $self->start,
            duration   => $self->duration,
            type       => 'raw',
        }, $user,
    ) };
    return $self->error(400, 'Bad request', $@) if $@;
    return $self->not_authorized unless $report->is_viewable_by($user);

    my @users;
    eval { 
        my $data = $report->_data;
        # Clean up the data
        for my $row (@$data) {
            my ($username, $count) = @$row;

            my $user = Socialtext::User->Resolve($username);
            warn "no user $username" unless $user;
            next unless $user;

            my $shared = $user->can_use_plugin_with(
                'people', $self->hub->current_user
            );

            my $user_id = $user->user_id;

            push @users, {
                title       => $user->guess_real_name,
                uri         => $shared ? "/?profile/$user_id" : undef,
                is_person   => 1,
                count       => $count,
            };
        }
    };
    return $self->error(400, 'Bad request', $@) if $@;

    $self->rest->header(-type => 'application/json');
    return encode_json({
        rows => \@users,
        meta  => {
            account   => $self->_account_data( $report ),
            workspace => $self->_workspace_data( $report ),
        },
    });
};

sub _account_data {
    my $self    = shift;
    my $report  = shift;

    # it is required that we either have a valid workspace or a valid
    # account.
    my $account = $report->account || $report->workspace->account();

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
