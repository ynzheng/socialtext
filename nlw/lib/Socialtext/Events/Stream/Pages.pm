package Socialtext::Events::Stream::Pages;
use Moose;
use MooseX::StrictConstructor;
use namespace::clean -except => 'meta';

extends 'Socialtext::Events::Stream';
with 'Socialtext::Events::Stream::HasPages';

__PACKAGE__->meta->make_immutable;
1;
