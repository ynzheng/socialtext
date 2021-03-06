package Socialtext::Rest::WebHooks;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Rest::Entity';
use Socialtext::JSON qw/encode_json decode_json/;
use Socialtext::WebHook;
use Socialtext::HTTP ':codes';

sub GET_json {
    my $self = shift;
    return $self->not_authorized unless $self->rest->user->is_business_admin;

    my $result = [];
    my $all_hooks = Socialtext::WebHook->All;
    for my $h (@$all_hooks) {
        push @$result, $h->to_hash;
    }
    return encode_json($result);
}

sub PUT_json {
    my $self = shift;
    my $rest = shift;
    return $self->not_authorized unless $rest->user->is_business_admin;

    my $content = $rest->getContent();
    my $object = decode_json( $content );
    if (ref($object) ne 'HASH') {
        $rest->header( -status => HTTP_400_Bad_Request );
        return 'Content should be a hash.';
    }
    my $hook;
    eval { 
        $object->{creator_id} = $rest->user->user_id;
        $hook = Socialtext::WebHook->Create(%$object),
    };
    if ($@) {
        warn $@;
        $rest->header( -status => HTTP_400_Bad_Request );
        return "$@";
    }

    $rest->header(
        -status => HTTP_201_Created,
        -Location => "/data/webhooks/" . $hook->id,
    );
    return '';
}

1;
