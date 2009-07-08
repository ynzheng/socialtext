package Socialtext::Events::Event::Person;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use namespace::clean -except => 'meta';

extends 'Socialtext::Events::Event';
with 'Socialtext::Events::Event::HasPerson';

enum 'PersonEventAction' => qw(
    edit_save
    tag_add
    tag_delete
    view
    watch_add
    watch_delete
);

has '+action' => (isa => 'PersonEventAction');

after 'build_hash' => sub {
    my $self = shift;
    my $h = shift;
    $h->{event_class} = 'person';
};

__PACKAGE__->meta->make_immutable;
1;
