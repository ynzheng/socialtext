package Socialtext::Job::WebHook;
# @COPYRIGHT@
use Moose;
use LWP::UserAgent;
use Socialtext::Log qw/st_log/;
use Socialtext::JSON qw/encode_json/;
use Fatal qw/open close/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

sub do_work {
    my $self = shift;

    my $ua = LWP::UserAgent->new;
    $ua->agent('Socialtext/WebHook');

    my $args = $self->arg;
    my $payload = ref($args->{payload}) ? encode_json($args->{payload})
                                        : $args->{payload};
    if (my $file = $ENV{ST_WEBHOOK_TO_FILE}) {
        # For testing
        open(my $fh, ">>$file");
        print $fh "URI: $args->{hook}{url}\n$payload\n\n";
        close $fh;
    }
    else {
        my $response = $ua->post( $args->{hook}{url},
            { json_payload => $payload },
        );
        st_log()->info("Triggered webhook '$args->{hook}{id}': "
                        . $response->status_line);
    }

    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;
