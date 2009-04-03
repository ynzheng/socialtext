package Socialtext::TheSchwartz;
use Moose;
use Socialtext::SQL qw/sql_execute get_dbh/;
use TheSchwartz::Moosified;
use namespace::clean -except => 'meta';

extends qw/TheSchwartz::Moosified/;

has '+verbose' => ( default => ($ENV{ST_JOBS_VERBOSE} ? 1 : 0) );
#has '+verbose' => ( default => 1 );

# make sure to call get_dbh() every time, basically
override 'databases' => sub { return [ get_dbh() ] };

around 'list_jobs' => sub {
    my $orig = shift;
    my $self = shift;
    my $args = (@_==1) ? shift : {@_};
    return $self->$orig($args);
};

__PACKAGE__->meta->make_immutable;
1;
