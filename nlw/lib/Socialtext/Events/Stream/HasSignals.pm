package Socialtext::Events::Stream::HasSignals;
use Moose::Role;
use Socialtext::Events::Source::SignalAccount;
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
   
    return unless @{$self->signals_account_ids};

    for my $account_id (@{ $self->signals_account_ids }) {
        push @$sources, $self->construct_source(
            'Socialtext::Events::Source::SignalAccount',
            account_id => $account_id,
        );
    }

    # TODO: is there a parameter to exclude direct-messages from certain feeds?
    push @$sources, $self->construct_source(
        'Socialtext::Events::Source::SignalPersonal',
        viewer => $self->viewer,
        user => $self->user,
    );
};

1;
