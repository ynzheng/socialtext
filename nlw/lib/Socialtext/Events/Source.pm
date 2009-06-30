package Socialtext::Events::Source;
use Moose::Role;
use namespace::clean -except => 'meta';

has 'viewer' => (
    is => 'ro', isa => 'Socialtext::User', required => 1,
);

has 'limit' => ( is => 'ro', isa => 'Int', default => 50 );
has 'before' => ( is => 'ro', isa => 'Num', default => 0x7fffffff );
has 'after' => ( is => 'ro', isa => 'Num', default => 0 );

requires 'prepare';
requires 'peek';
requires 'next';
requires 'skip';

1;
