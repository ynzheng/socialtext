package Socialtext::Events::Stream::HasPeople;
use Moose::Role;
use Socialtext::Events::Source::PersonVisible;
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

    my $ids = $self->people_account_ids;
    return unless $ids && @$ids;
    push @$sources, $self->construct_source(
        'Socialtext::Events::Source::PersonVisible',
        visible_account_ids => $ids,
    );
};

1;
