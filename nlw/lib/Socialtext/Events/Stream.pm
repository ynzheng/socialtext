package Socialtext::Events::Stream;
use Moose::Role;
use MooseX::AttributeHelpers;
use Socialtext::Events::FilterParams;
use Clone qw/clone/;
use namespace::clean -except => 'meta';

with 'Socialtext::Events::Source';

has 'sources' => (
    is => 'ro', isa => 'ArrayRef[Socialtext::Events::Source]',
    lazy_build => 1,
);
requires '_build_sources';

has 'offset' => ( is => 'ro', isa => 'Int', default => 0 );

has '_remaining' => (
    is => 'rw', isa => 'Int',
    metaclass => 'Counter',
    provides => {
        dec => '_dec_remaining', 
    },
);
has '_assembled' => ( is => 'rw', isa => 'Bool', default => undef );
has '_skipped' => ( is => 'rw', isa => 'Bool', default => undef );

has '_queue' => ( is => 'rw', isa => 'ArrayRef', init_arg => undef, lazy_build => 1 );

sub effective_limit {
    my $self = shift;
    return $self->offset + $self->limit;
}

sub construct_source {
    my $self = shift;
    my $class = shift;
    return $class->new(
        @_,
        viewer => $self->viewer,
        user => $self->user,
        limit => $self->effective_limit,
        filter => clone($self->filter),
    );
}

sub all {
    my $self = shift;
    my @events;
    $#events = $self->limit - 1; $#events = -1; # preallocate space
    while (my $e = $self->next) {
        push @events, $e;
    }
    return @events if wantarray;
    return \@events;
}

sub all_hashes {
    my $self = shift;
    my @hashes;
    $#hashes = $self->limit - 1; $#hashes = -1; # preallocate space
    while (my $e = $self->next) {
        push @hashes, $e->build_hash({});
    }
    return @hashes if wantarray;
    return \@hashes;
}

# force the creation of all sources
sub assemble {
    my $self = shift;
    return if $self->_assembled;
    for my $src (@{$self->sources}) {
        $src->assemble if $src->does('Socialtext::Events::Stream');
    }
    $self->_assembled(1);
}

sub prepare {
    my $self = shift;

    $self->assemble;
    $self->_skipped($self->offset ? undef : 1); # no skip if no offset
    $self->_remaining($self->limit);

    my $q = $self->_queue; # force builder
    $self->_check_if_done();

    return;
}

sub next {
    my $self = shift;

    return unless $self->_remaining;

    unless ($self->_skipped) {
        $self->_skip_ahead($self->offset);
        $self->_skipped(1);
    }

    my $next;
    if (my $src = $self->_shift_queue) {
        $next = $src->next;
        $self->_push_queue($src);
    }

    $self->_dec_remaining;
    $self->_check_if_done();
    return $next;
}

sub skip {
    my $self = shift;
    return unless $self->_remaining;
    $self->_skip_ahead(1);
    $self->_dec_remaining;
    $self->_check_if_done();
    return;
}

sub peek {
    my $self = shift;

    return unless $self->_remaining;

    unless ($self->_skipped) {
        $self->_skip_ahead($self->offset);
        $self->_skipped(1);
    }

    my $epoch = $self->_peek_queue;
    return $epoch;
}

sub _skip_ahead {
    my $self = shift;
    my $skip = shift;

    while ($skip-- > 0) {
        my $src = $self->_shift_queue;
        next unless $src;
        $src->skip;
        $self->_push_queue($src);
    }
    $self->_check_if_done();
}

sub _check_if_done {
    my $self = shift;
    if ($self->_has_queue && @{$self->_queue} == 0) {
        $self->_clear_queue;
        $self->clear_sources;
        $self->_assembled(undef);
        $self->_remaining(0);
    }
}


sub _build__queue {
    my $self = shift;

    $_->prepare for @{$self->sources};

    my @queue = sort {$b->[0] <=> $a->[0]} 
        grep { defined $_->[0] }
        map { [$_->peek || undef, $_] }
        @{ $self->sources };

    return \@queue;
}

sub _peek_queue {
    my $self = shift;
    my $first = $self->_queue->[0];
    return unless $first;
    return $first->[0];
}

sub _shift_queue {
    my $self = shift;
    my $first = shift @{$self->_queue};
    return unless $first;
    return $first->[1];
}

sub _push_queue {
    my $self = shift;
    my $src = shift;

    my $new_epoch = $src->peek;
    return unless $new_epoch;

    my $pair = [$new_epoch,$src];
    my $q = $self->_queue;
    if (@$q == 0 || $q->[0][0] < $new_epoch) {
        unshift @$q, $pair;
    }
    else {
        # TODO: use a heap, maybe (this sort is stable, however)
        @$q = sort {$b->[0] <=> $a->[0]} $pair, @$q;
    }

    return;
}

1;
