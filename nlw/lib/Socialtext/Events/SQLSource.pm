package Socialtext::Events::SQLSource;
use Moose::Role;
#use Moose;
use MooseX::AttributeHelpers;
use Socialtext::SQL qw/:exec/;
use namespace::clean -except => 'meta';

has 'sql_results' => (
    is => 'rw', isa => 'ArrayRef[HashRef]',
    metaclass => 'Collection::Array',
    lazy_build => 1,
    provides => {
        'first' => 'peek_sql_result',
        'shift' => 'next_sql_result',
    },
);

# write 'next' like this:
# sub next {
#     My::Event::Type->new(shift->next_sql_result);
# }
requires 'next';
requires 'query_and_binds';

sub _build_sql_results {
    my $self = shift;
    my ($sql, $binds) = $self->query_and_binds();
    my $sth = sql_execute($sql, @$binds);
    return [] unless $sth->rows > 0;
    return $sth->fetchall_arrayref({});
}

sub prepare {
    my $r = shift->sql_results; # force builder
    return @$r > 0;
}

sub peek {
    my $self = shift;
    my $first = $self->peek_sql_result;
    return unless $first;
    return $first->{at_epoch};
}

sub skip {
    shift->next_sql_result;
    return;
}

sub columns {
    return 'at, EXTRACT(epoch FROM at) AS at_epoch, '.
        'action, actor_id, tag_name, context';
}

1;
