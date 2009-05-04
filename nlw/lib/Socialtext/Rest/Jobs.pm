package Socialtext::Rest::Jobs;
# @COPYRIGHT@
use warnings;
use strict;

use base 'Socialtext::Rest::Collection';

use Class::Field qw( const field );
use Socialtext::JSON;
use Socialtext::HTTP ':codes';
use Socialtext::Exceptions;
use Socialtext::Jobs;
use Socialtext::l10n qw(loc);

sub allowed_methods {'GET'}
sub collection_name { loc('Jobs') }

field errors => [];

sub if_authorized {
    my $self = shift;
    my $method = shift;
    my $call = shift;

    return $self->bad_method
        unless $self->allowed_methods =~ /\b\Q$method\E\b/;

    return $self->not_authorized
        unless $self->_user_is_business_admin_p;

    return $self->$call(@_);
}

sub get_resource {
    my $self = shift;
    my $rest = shift;

    my $stat = Socialtext::Jobs->stat_jobs();

    my $results = [];
    for my $type (keys %$stat) {
        (my $shortname = $type) =~ s/^Socialtext::Job:://;
        push @$results, {name => $shortname, %{$stat->{$type}}}
    }

    return $results;
}

sub _entity_hash { }

sub resource_to_html {
    my ($self, $job_stats) = @_;
    my @column_order = qw(name queued delayed grabbed);
    my %avail = map {$_=>1} keys %{ $job_stats->[0] };
    delete @avail{@column_order};
    push @column_order, sort keys %avail;
    $self->_template_render('data/job_stats.html' => { 
        job_stats => $job_stats,
        columns => \@column_order,
    });
}

1;
