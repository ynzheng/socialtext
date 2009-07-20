package Socialtext::Events::Source::SignalPersonal;
use Moose;
use MooseX::StrictConstructor;
use Socialtext::SQL::Builder qw/sql_abstract/;
use Socialtext::Events::Event::Signal;
use namespace::clean -except => 'meta';

with 'Socialtext::Events::Source', 'Socialtext::Events::SQLSource';

use constant event_type => 'Socialtext::Events::Event::Signal';

sub query_and_binds {
    my $self = shift;

    my @where = (
        event_class => 'signal',
        \"is_direct_signal(actor_id,person_id)",
    );

    if ($self->viewer_id == $self->user_id) {
        push @where, -or => [
            actor_id => $self->viewer_id,
            person_id => $self->viewer_id,
        ];
    }
    else {
        # direct between the viewer and the user
        push @where, -or => [
            {
                actor_id => $self->viewer_id,
                person_id => $self->user_id,
            },
            {
                actor_id => $self->user_id,
                person_id => $self->viewer_id,
            },
        ];
    }

    push @where, -nest => $self->filter->generate_filter(
        qw(before after actor_id person_id)
    );

    my $sa = sql_abstract();
    my ($sql, @binds) = $sa->select(
        'event', $self->columns, \@where, 'at DESC', $self->limit
    );
    return $sql, \@binds;
}

around 'columns' => sub {
    return shift->().', person_id, signal_id';
};

__PACKAGE__->meta->make_immutable;
1;
