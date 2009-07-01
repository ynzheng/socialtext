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

requires 'prepare';
requires 'peek';
requires 'next';
requires 'skip';

package Socialtext::Events::EmptySource;
use Moose;
with 'Socialtext::Events::Source';

sub prepare { }
sub peek    { undef }
sub next    { undef }
sub skip    { }

1;
