package Socialtext::Job::Cmd;
use Moose;
use IPC::Run ();
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

override 'keep_exit_status_for' => sub { 86400 };

sub do_work {
    my $self = shift;
    my $cmd = $self->arg->{cmd};
    my $args = $self->arg->{args} || [];

    my $output = '';
    my $h = IPC::Run::start(
        [$cmd, @$args],
        undef, \$output, \$output, 
        IPC::Run::timeout(10)
    );

    if ($h->finish) {
        $self->completed($output);
    }
    else {
        $self->failed($?, $output);
    }
}

__PACKAGE__->meta->make_immutable;
1;
