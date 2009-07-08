package Socialtext::Events::Event::HasPerson;
use Moose::Role;
use namespace::clean -except => 'meta';

has 'person_id' => (is => 'ro', isa => 'Int');
has 'person' => (is => 'ro', isa => 'Maybe[Socialtext::User]', lazy_build => 1);

sub _build_person { Socialtext::User->new(user_id => $_[0]->person_id) }

requires 'add_user_to_hash';
after 'build_hash' => sub {
    my $self = shift;
    my $hash = shift;

    if ($self->person_id && $self->person) {
        $hash->{person} ||= {};
        $self->add_user_to_hash('person' => $self->person, $hash);
    }
};

1;
