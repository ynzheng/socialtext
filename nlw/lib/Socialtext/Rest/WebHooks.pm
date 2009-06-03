package Socialtext::Rest::WebHooks;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Rest::Collection';
use Socialtext::JSON qw/encode_json/;
use Socialtext::WebHook;

sub GET_json {
    my $self = shift;

    my $result = [];
    my $all_hooks = Socialtext::WebHook->All;
    for my $h (@$all_hooks) {
        push @$result, $h->to_hash;
    }
    return encode_json($result);
}

1;
