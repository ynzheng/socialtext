package Socialtext::Events::Event;
use Moose;
use namespace::clean -except => 'meta';

has 'at_epoch' => ( is => 'ro', isa => 'Num', required => 1 );

has 'actor_id' => (is => 'ro', isa => 'Int');
has 'context' => (is => 'ro', isa => 'HashRef');

__PACKAGE__->meta->make_immutable;
1;
