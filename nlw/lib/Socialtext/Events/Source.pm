package Socialtext::Events::Source;
use Moose::Role;
use Socialtext::Events::FilterParams;
use namespace::clean -except => 'meta';

has 'viewer' => (
    is => 'ro', isa => 'Socialtext::User', required => 1,
    handles => {
        viewer_id => 'user_id',
    },
);

has 'user' => (
    is => 'ro', isa => 'Socialtext::User', required => 1,
    lazy => 1,
    default => sub { shift->viewer },
    handles => {
        user_id => 'user_id',
    },
);

has 'limit' => ( is => 'ro', isa => 'Int', default => 50 );

has 'filter' => (
    is => 'ro', isa => 'Socialtext::Events::FilterParams',
    handles => [qw(before after)],
);

requires 'prepare'; # returns false if no results
requires 'peek';
requires 'next';
requires 'skip';

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

package Socialtext::Events::EmptySource;
use Moose;
with 'Socialtext::Events::Source';

sub prepare { undef }
sub peek    { undef }
sub next    { undef }
sub skip    { undef }

1;
