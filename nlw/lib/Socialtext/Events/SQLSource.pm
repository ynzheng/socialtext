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
    my $rows = $sth->fetchall_arrayref({}) || [];
    return $rows;
}

sub prepare {
    shift->sql_results;
    return;
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

1;
