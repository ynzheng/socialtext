#!perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext tests => 12;
use Test::Socialtext::Ceqlotron;

BEGIN {
    use_ok 'Socialtext::Job::Cmd';
    use_ok 'Socialtext::Jobs';
    use_ok 'Socialtext::JobCreator';
}
END { ceq_kill() }

ok(Socialtext::Job::Cmd->isa('Socialtext::Job'));

fixtures( 'db', 'base_config' );

my $Ceq_bin = ceq_bin();
ok -x $Ceq_bin;
Socialtext::Jobs->clear_jobs();
ceq_config(
    period => 0.1,
    polling_period => 0.1,
    max_concurrency => 2,
);

touch_a_file: {
    ceq_fast_forward();

    my $ceq_pid = ceq_start();
    my @startup = ceq_get_log_until(
        qr/Ceqlotron master: fork, concurrency now 2/);

    my $touchfile = "t/tmp/job-cmd.$$";
    for my $n (1 .. 2) {
        ok(Socialtext::JobCreator->insert(
            'Socialtext::Job::Cmd',
            { 
                cmd => '/usr/bin/touch',
                args => ["$touchfile.$n"],
            },
        ), 'inserted job');
    }
    sleep 1; # wait for kids to pick up the job
    kill(INT => $ceq_pid); # ask ceq to exit
    my @shutdown = ceq_get_log_until(qr/master: exiting/);
    
    ok -f "$touchfile.$_", "$touchfile.$_ exists" for (1 .. 2);
}

exit;
