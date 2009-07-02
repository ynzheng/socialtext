package Socialtext::Events::Event::HasPerson;
use Moose::Role;
use namespace::clean -except => 'meta';

has 'person_id' => (is => 'ro', isa => 'Int');
has 'person' => (is => 'ro', isa => 'Socialtext::User', lazy_build => 1);

sub _build_person { Socialtext::User->new(user_id => $_[0]->person_id) }

sub person_uri { "/data/people/".$self->person_id }

after 'build_hash' => sub {
    my $self = shift;
    my $hash = shift;

    $hash->{person}{id} = $self->person_id;
    $hash->{person}{uri} = $self->person_uri;
};

1;
