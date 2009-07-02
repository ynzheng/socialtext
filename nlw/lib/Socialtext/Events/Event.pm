package Socialtext::Events::Event;
use Moose;
use MooseX::StrictConstructor;
use Carp qw/croak/;
use namespace::clean -except => 'meta';

has 'at_epoch' => ( is => 'ro', isa => 'Num', required => 1 );
has 'at' => ( is => 'ro', isa => 'Str', required => 1 );
has 'at_dt' => ( is => 'ro', isa => 'DateTime', lazy_build => 1 );

has 'actor_id' => (is => 'ro', isa => 'Int', required => 1 );
has 'action' => (is => 'ro', isa => 'Str', required => 1 );
has 'context' => (is => 'ro', isa => 'Maybe[HashRef]');

# roles/extending classes should hook this with an 'after' sub
sub build_hash {
    my $self = shift;
    my $hash = shift
        or croak 'build_hash requires an empty hash parameter';

    $hash->{at} = $self->at;

    $hash->{actor}{id} = $self->actor_id;
    $hash->{actor}{uri} = "/data/people/".$self->actor_id;

    $hash->{action} = $self->action;

    $hash->{context} = $self->context;

    return $hash;
}

__PACKAGE__->meta->make_immutable;
1;
