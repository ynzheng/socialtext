package Socialtext::Job::Test;
# @COPYRIGHT@
use Moose;
use Socialtext::Log qw/st_log/;
use Time::HiRes qw/sleep/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

our $Work_count = 0;
our $Retries = 0;

override 'max_retries' => sub { $Retries };

sub do_work {
    my $self = shift;
    my $args = $self->arg;

    die "failed!\n" if $args->{fail};
    $Work_count++;

    st_log->debug($args->{message})      if $args->{message};
    sleep $args->{sleep}                 if $args->{sleep};
    st_log->debug($args->{post_message}) if $args->{post_message};

    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;
