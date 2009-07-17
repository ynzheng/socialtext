package Socialtext::Events::Stream::HasSignals;
use Moose::Role;
use Socialtext::Events::Source::Signals;
use Socialtext::Events::Source::SignalPersonal;
use namespace::clean -except => 'meta';

has 'signals_account_ids' => (
    is => 'rw', isa => 'ArrayRef[Int]',
    lazy_build => 1,
);

before 'assemble' => sub {
    my $self = shift;
    $self->signals_account_ids; # force builder
    return;
};

sub _build_signals_account_ids { $_[0]->account_ids_for_plugin('signals'); }

after 'add_sources' => sub {
    my $self = shift;
    my $sources = shift;
   
    my $ids = $self->signals_account_ids;
    return unless $ids && @$ids;

    push @$sources, $self->construct_source(
        'Socialtext::Events::Source::Signals',
        account_ids => $ids,
    );

    # TODO: is there a parameter to exclude direct-messages from certain feeds?
    push @$sources, $self->construct_source(
        'Socialtext::Events::Source::SignalPersonal',
        viewer => $self->viewer,
        user => $self->user,
    );
};

1;
