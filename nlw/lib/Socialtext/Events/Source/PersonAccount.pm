package Socialtext::Events::Source::PersonAccount;
use Moose;
use Socialtext::SQL::Builder qw/sql_abstract/;
use Socialtext::Events::Event::Person;
use namespace::clean -except => 'meta';

with 'Socialtext::Events::Source', 'Socialtext::Events::SQLSource';

has 'account_id' => ( is => 'ro', isa => 'Int', required => 1 );

sub next { 
    my $self = shift;
    my $e = Socialtext::Events::Event::Person->new($self->next_sql_result);
    $e->source($self);
    return $e;
}

sub query_and_binds {
    my $self = shift;

    # person_id has a much lower cardinality; joining on it will result in a
    # lot fewer queries that we have to run the EXISTS check for the actor_id
    my $person_sql = 
        q{person_id IN (SELECT user_id FROM account_user WHERE account_id = ?)};
    my $actor_sql = q{EXISTS(
        SELECT 1 FROM account_user WHERE account_id=? AND user_id=actor_id
    )};

    my @where = (
        event_class => 'person',
        ($self->filter->contributions ? 
            \"is_profile_contribution(action)" : ()),
        \[$person_sql => $self->account_id],
        \[$actor_sql => $self->account_id],
    );

    $self->add_where_clauses(\@where);

    if ($self->filter->followed) {
        my $f = $self->followed_clause;
        push @where, -or => [
            person_id => \[$f => $self->viewer_id],
            actor_id =>  \[$f => $self->viewer_id],
        ];
    }

    my $sa = sql_abstract();
    my ($sql, @binds) = $sa->select(
        'event', $self->columns, \@where, 'at DESC', $self->limit
    );
    return $sql, \@binds;
}

sub add_where_clauses {
    my $self = shift;
    my $where = shift;
    push @$where, -nest => $self->filter->generate_filter(
        qw(before after actor_id person_id tag_name)
    );
}

around 'columns' => sub {
    return shift->().', person_id';
};

__PACKAGE__->meta->make_immutable;
1;
