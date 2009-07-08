package Socialtext::Events::Stream::HasPeople;
use Moose::Role;
use Socialtext::Events::Source::PersonAccount;
use namespace::clean -except => 'meta';

requires 'assemble';
requires 'add_sources';
requires 'account_ids_for_plugin';

has 'people_account_ids' => (
    is => 'rw', isa => 'ArrayRef[Int]',
    lazy_build => 1,
);

before 'assemble' => sub {
    my $self = shift;
    $self->people_account_ids; # force builder
    return;
};

sub _build_people_account_ids { $_[0]->account_ids_for_plugin('people'); }

after 'add_sources' => sub {
    my $self = shift;
    my $sources = shift;

    for my $account_id (@{ $self->people_account_ids }) {
        push @$sources, $self->construct_source(
            'Socialtext::Events::Source::PersonAccount',
            account_id => $account_id,
        );
    }
};

1;
