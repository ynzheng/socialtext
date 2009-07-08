package Socialtext::Events::Stream::Regular;
use Moose;
use MooseX::StrictConstructor;
use namespace::clean -except => 'meta';

extends 'Socialtext::Events::Stream';
with qw(
    Socialtext::Events::Stream::HasPages
    Socialtext::Events::Stream::HasPeople
    Socialtext::Events::Stream::HasSignals
);

__PACKAGE__->meta->make_immutable;
1;
