package Socialtext::Rest::ReportAdapter;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Rest::Entity';

sub adapter {
    my $self = shift;
    require Socialtext::Reports::REST;
    return $self->{_adapter} if $self->{_adapter};
    $Socialtext::Reports::REST::HUB = $self->hub;
    $self->{_adapter} = Socialtext::Reports::REST->new();
    $self->{_adapter}->query($self->rest->query);
    return $self->{_adapter};
}

sub GET_html {
    my $self = shift;
    return $self->adapter->handle_report(
        $self->name, $self->start, $self->duration, 'html'
    );
}

sub GET_json {
    my $self = shift;
    return $self->adapter->handle_report(
        $self->name, $self->start, $self->duration, 'json'
    );
}

1;
