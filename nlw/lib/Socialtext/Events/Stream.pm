package Socialtext::Events::Stream;
use Moose::Role;
use MooseX::AttributeHelpers;
use namespace::clean -except => 'meta';

with 'Socialtext::Events::Source';

has 'sources' => (
    is => 'ro', isa => 'ArrayRef[Socialtext::Events::Source]',
    lazy_build => 1,
);

has 'offset' => ( is => 'ro', isa => 'Int', default => 0 );

has 'skipped' => (
    is => 'rw', isa => 'Bool', default => undef
);

has 'remaining' => (
    is => 'rw', isa => 'Int',
    metaclass => 'Counter',
    provides => {
        dec => 'dec_remaining', 
    }
);

has '_queue' => ( is => 'rw', isa => 'ArrayRef', init_arg => undef );

requires '_build_sources';

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
        limit => $self->effective_limit,
        before => $self->before,
        after => $self->after,
    );
}

sub prepare {
    my $self = shift;
    for my $src (@{$self->sources}) {
        $src->prepare;
    }

    $self->skipped($self->offset ? undef : 1); # no skip if no offset
    $self->remaining($self->limit);

    $self->_queue([]);
    for my $src (@{$self->sources}) {
        $self->_push_queue($src);
    }

    return;
}

sub next {
    my $self = shift;

    return unless $self->remaining;

    unless ($self->skipped) {
        $self->_skip_ahead($self->offset);
        $self->skipped(1);
    }

    my $next;
    if (my $src = $self->_shift_queue) {
        $next = $src->next;
        $self->_push_queue($src);
    }

    $self->dec_remaining;
    return $next;
}

sub skip {
    my $self = shift;
    return unless $self->remaining;
    $self->_skip_ahead(1);
    $self->dec_remaining;
    return;
}

sub peek {
    my $self = shift;

    return unless $self->remaining;

    unless ($self->skipped) {
        $self->_skip_ahead($self->offset);
        $self->skipped(1);
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

    my $new_pair = [$new_epoch,$src];
    my $queue = $self->_queue;
    if (!@$queue) {
        @$queue = ($new_pair);
    }
    elsif ($queue->[0][0] < $new_epoch) {
        unshift @$queue, $new_pair;
    }
    elsif ($queue->[$#$queue][0] > $new_epoch) {
        push @$queue, $new_pair;
    }
    else {
        # TODO: use a heap
        @$queue = sort {$b->[0] <=> $a->[0]} @$queue, $new_pair;
    }

    return;
}

1;
