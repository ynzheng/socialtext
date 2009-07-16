package Socialtext::Events::Stream;
use Moose;
use MooseX::AttributeHelpers;
use MooseX::StrictConstructor;
use Socialtext::SQL qw/:exec/;
use Socialtext::Events::FilterParams;
use Array::Heap;
use namespace::clean -except => 'meta';

with 'Socialtext::Events::Source', 'MooseX::Traits';

# new_with_traits() will apply this prefix to traits:
has '+_trait_namespace' => (default => 'Socialtext::Events::Stream');

has '+filter' => (required => 1);

has 'sources' => (
    is => 'rw', isa => 'ArrayRef[Socialtext::Events::Source]',
    metaclass => 'Collection::List',
    lazy_build => 1,
    auto_deref => 1,
    provides => {
        count => 'source_count',
    },
);

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

has '_queue' => (
    is => 'rw', isa => 'ArrayRef',
    init_arg => undef,
    lazy_build => 1,
);

sub effective_limit {
    my $self = shift;
    return $self->offset + $self->limit;
}

sub construct_source {
    my $self = shift;
    my $class = shift;
    my $constructor
        = $class->can('new_with_traits') ? 'new_with_traits' : 'new';
    return $class->$constructor(
        filter => $self->filter,
        @_,
        viewer => $self->viewer,
        user => $self->user,
        limit => $self->effective_limit,
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
    for my $src ($self->sources) {
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
    return @$q > 0;
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

    my @sources = grep {
        $_->prepare && defined $_->peek;
    } $self->sources;

    # negate to reverse order
    my @queue = map { [-$_->peek, $_] } @sources;
    make_heap @queue;

    return \@queue;
}

sub _peek_queue {
    my $self = shift;
    my $first = $self->_queue->[0];
    return unless $first;
    return -$first->[0];
}

sub _shift_queue {
    my $self = shift;
    my $first = pop_heap @{$self->_queue};
    return unless $first;
    return $first->[1];
}

sub _push_queue {
    my $self = shift;
    my $src = shift;

    return unless $src;
    my $new_epoch = $src->peek;
    return unless $new_epoch;
    push_heap @{$self->_queue}, [-$new_epoch,$src];
    return;
}


sub account_ids_for_plugin {
    my $self = shift;
    my $plugin = shift;

    my $sql;
    my @bind;
    if ($self->user_id == $self->viewer_id) {
        $sql = qq{
            SELECT DISTINCT account_id
            FROM account_user viewr
            JOIN account_plugin USING (account_id)
            WHERE plugin = ?
                AND viewr.user_id = ?
        };
        @bind = ($plugin, $self->viewer_id);
    }
    else {
        $sql = qq{
            SELECT DISTINCT account_id
            FROM account_user viewr
            JOIN account_plugin USING (account_id)
            JOIN account_user usr USING (account_id)
            WHERE plugin = ?
                AND viewr.user_id = ?
                AND usr.user_id = ?
        };
        @bind = ($plugin, $self->viewer_id, $self->user_id);
    }

    my $sth = sql_execute($sql, @bind);
    my $rows = $sth->fetchall_arrayref;
    my @ids = map {$_->[0]} @$rows;
    return \@ids;
}

sub _build_sources {
    my $self = shift;

    my @sources;
    $self->add_sources(\@sources);
    return \@sources;
}

sub add_sources {
    my $self = shift;
    my $sources = shift;
} # no-op

__PACKAGE__->meta->make_immutable;
1;