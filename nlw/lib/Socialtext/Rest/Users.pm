package Socialtext::Rest::Users;
# @COPYRIGHT@

use warnings;
use strict;

use Class::Field qw( const field );
use Socialtext::JSON;
use Socialtext::HTTP ':codes';
use Socialtext::User;
use Socialtext::Exceptions;
use Socialtext::User::Find;

use base 'Socialtext::Rest::Collection';

sub allowed_methods {'GET, POST'}

field errors        => [];

sub if_authorized {
    my $self = shift;
    my $method = shift;
    my $call = shift;

    if ($method eq 'POST') {
        return $self->not_authorized
            unless $self->_user_is_business_admin_p;
    }
    elsif ($method eq 'GET') {
        return $self->not_authorized
            if ($self->rest->user->is_guest);
    }
    else {
        return $self->bad_method;
    }

    return $self->$call(@_);
}

sub POST_json {
    my $self = shift;
    return $self->if_authorized('POST', '_POST_json', @_);
}

sub _POST_json {
    my $self = shift;
    my $rest = shift;

    my $create_request_hash = decode_json($rest->getContent());

    unless ($create_request_hash->{username} and
            $create_request_hash->{email_address}) 
    {
        Socialtext::Exception->throw(
            error => "username, email_address required",
            http_status => HTTP_400_Bad_Request,
        );
    }
    
    my ($new_user) = eval {
        Socialtext::User->create(
            %{$create_request_hash},
            creator => $self->rest->user()
        );
    };

    if (my $e = Exception::Class->caught('Socialtext::Exception::DataValidation')) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
            -type   => 'text/plain'
        );
        return join("\n", $e->messages);
    }
    elsif ($@) {
        Socialtext::Exception->throw(
            error => "Unable to create user: $@",
            http_status => HTTP_400_Bad_Request,
        );
    }

    $rest->header(
        -status   => HTTP_201_Created,
        -type     => 'application/json',
        -Location => $self->full_url('/', $new_user->username()),
    );
    return '';
}

sub create_user_find {
    my $self = shift;
    my $limit = $self->rest->query->param('count') ||
                $self->rest->query->param('limit') ||
                25;
    my $offset = $self->rest->query->param('offset') || 0;

    my $filter = $self->rest->query->param('filter');

    return Socialtext::User::Find->new(
        viewer => $self->rest->user,
        limit => $limit,
        offset => $offset,
        filter => $filter,
    )
}

sub get_resource {
    my $self = shift;
    my $rest = shift;

    my $f = eval { $self->create_user_find };
    if ($@) {
        warn $@;
        Socialtext::Exception->throw(
            error => "Bad request or illegal filter options",
            http_status => HTTP_400_Bad_Request,
        );
    }

    my $results = eval { $f->typeahead_find };
    if ($@) {
        warn $@;
        Socialtext::Exception->throw(
            error => "Illegal filter or query error",
            http_status => HTTP_400_Bad_Request,
        );
    }

    return $results || [];
}

sub _entity_hash {
}

1;
