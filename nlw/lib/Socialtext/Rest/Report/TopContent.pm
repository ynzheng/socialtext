package Socialtext::Rest::Report::TopContent;
# @COPYRIGHT@
use Moose;
use Socialtext::JSON qw/encode_json/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::ReportAdapter';

override 'GET_json' => sub {
    my $self = shift;
    my $user = $self->rest->user;

    my $report = eval { $self->adapter->_build_report(
        'TopContentByPage', {
            start_time => $self->start,
            duration   => $self->duration,
            type       => 'raw',
            query_args => {
                top => 12,
            },
        }, $user,
    ) };
    return $self->error(400, 'Bad request', $@) if $@;

    my $wksp = eval { $report->workspace };
    return $self->error(400, 'Bad request', $@) if $@;
    $self->hub->current_workspace($wksp);
    
    return $self->not_authorized unless $report->is_viewable_by($user);

    my $data;
    eval { 
        $data = $report->_data;

        # Clean up the data
        my %clean_data;
        for my $row (@$data) {
            my ($page_id, $count) = @$row;
            next if $page_id =~ m/^untitled[_\s]page/i;

            my $page;
            if ($page_id eq '') {
                $page = $self->hub->pages->new_from_uri($wksp->title);
            }
            else {
                $page = eval { $self->hub->pages->new_from_uri($row->[0]) };
                if ($@) { warn $@; next }
            }
            $clean_data{$page->title} += $row->[1];
        }
        $data = [
            map { [ $_ => $clean_data{$_} ] }
                sort { $clean_data{$b} <=> $clean_data{$a} }
                    keys %clean_data
        ];
    };
    return $self->error(400, 'Bad request', $@) if $@;

    $self->rest->header(-type => 'application/json');
    return encode_json($data);
};

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
