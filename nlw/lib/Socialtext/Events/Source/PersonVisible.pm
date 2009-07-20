package Socialtext::Events::Source::PersonVisible;
use Moose;
use Socialtext::SQL::Builder qw/sql_abstract/;
use Socialtext::Events::Event::Person;
use namespace::clean -except => 'meta';

with 'Socialtext::Events::Source', 'Socialtext::Events::SQLSource';

has 'visible_account_ids' => ( is => 'ro', isa => 'ArrayRef' );
has 'activity_mode' => ( is => 'ro', isa => 'Bool', default => undef );

use constant event_type => 'Socialtext::Events::Event::Person';

sub _visible_exists {
    my $self = shift;
    my $outer_field = shift;
    my $sa = sql_abstract();
    my ($sql, @binds) = $sa->select(
        'account_user', '1', {-and => [
            \"user_id = $outer_field",
            account_id => {-in => $self->visible_account_ids},
        ]},
    );
    return \["EXISTS($sql)", @binds];
}

sub query_and_binds {
    my $self = shift;

    my @where = (
        event_class => 'person',
        ($self->filter->contributions ? 
            \"is_profile_contribution(action)" : ()),
    );

    push @where,
        $self->_visible_exists('person_id'),
        $self->_visible_exists('actor_id');

    if ($self->activity_mode) {
        my $activity = q{
            -- target ix_event_person_contribs_actor
            (event_class = 'person' AND is_profile_contribution(action)
                AND actor_id = ?)
            OR
            -- target ix_event_person_contribs_person
            (event_class = 'person' AND is_profile_contribution(action)
                AND person_id = ?)
        };
        push @where, \[$activity, ($self->user_id) x 2];
    }

    push @where, -nest => $self->filter->generate_filter(
        qw(before after action actor_id person_id tag_name)
    );

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

around 'columns' => sub {
    return shift->().', person_id';
};

__PACKAGE__->meta->make_immutable;
1;
