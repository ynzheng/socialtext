package Socialtext::Jobs;
# @COPYRIGHT@
use MooseX::Singleton;
use Socialtext::TheSchwartz;
use Socialtext::SQL qw/sql_execute/;
use Module::Pluggable search_path => 'Socialtext::Job',
    sub_name => 'job_types', require => 0;
use Memoize;
use Carp qw/croak/;
use namespace::clean -except => [qw(meta job_types)];

has '_client' => (
    is => 'ro', isa => 'Socialtext::TheSchwartz',
    lazy_build => 1,
    handles => qr/^.+$/,
);

around 'insert' => sub {
    croak 'Use Socialtext::JobCreator->insert to create jobs'
};

sub _build__client { Socialtext::TheSchwartz->new() }

memoize 'job_types';

sub load_all_jobs {
    my $self = shift;
    for my $job_type ($self->job_types) {
        eval "require $job_type";
        croak $@ if $@;
    }
}

sub can_do_all {
    my $self = shift;
    $self->load_all_jobs();
    $self->can_do($_) for $self->job_types;
}

sub clear_jobs { sql_execute('DELETE FROM job') }

sub Unlimit_list_jobs {
    Socialtext::TheSchwartz->Unlimit_list_jobs();
}

__PACKAGE__->meta->make_immutable;
1;
