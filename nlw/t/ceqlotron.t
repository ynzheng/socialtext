#!perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext tests => 27;
use File::LogReader;
use Socialtext::AppConfig;

use constant NOISY => 0; # turn this on for diag()

BEGIN {
    use_ok 'Socialtext::Jobs';
    use_ok 'Socialtext::JobCreator';
}

fixtures( 'db', 'base_config' );

my $NLW_log_file = 't/tmp/log/nlw.log';
system("touch $NLW_log_file");
my $nlwlog = File::LogReader->new( filename => $NLW_log_file );

my $Ceq_bin = 'bin/ceqlotron';
ok -x $Ceq_bin;
Socialtext::Jobs->clear_jobs();

system("st-config set ceqlotron_period 0.1 > /dev/null") and die 'unable to set period';
system("st-config set ceqlotron_polling_period 0.1 > /dev/null") and die 'unable to set period';
system("st-config set ceqlotron_max_concurrency 2 > /dev/null") and die 'unable to set concurrency';

Start_and_stop: {
    fast_forward();

    my $ceq_pid = ceq_start();

    my @startup = get_more_lines_until(
        qr/Ceqlotron master: fork, concurrency now 2/);

    ok grep(qr/ceqlotron starting/,@startup), 'ceq logged startup msg';
    my @started_kids = grep /Ceqlotron worker: starting/, @startup;
    is scalar(@started_kids), 2, 'two workers started up';

    ok kill(0 => $ceq_pid), "ceq pid $ceq_pid is alive";

    Start_another_ceq: {
        system($Ceq_bin); # should start & daemonize
        my $new_pid = qx($Ceq_bin --pid); chomp $new_pid;
        is $new_pid, $ceq_pid, 'ceq pid did not change';
    }

    fast_forward();

    ok kill(INT => $ceq_pid), "sent INT to $ceq_pid";
    my @shutdown = get_more_lines_until(qr/master: exiting/);

    ok !kill(0 => $ceq_pid), "ceq pid $ceq_pid is no longer alive";

    my @stopped_kids = grep /Ceqlotron worker: exiting/, @shutdown;
    is scalar(@stopped_kids), 2, 'both workers shutdown';
}

Process_a_job: {
    fast_forward();
    my $ceq_pid = ceq_start();

    my @startup = get_more_lines_until(
        qr/Ceqlotron master: fork, concurrency now 2/);

    Socialtext::JobCreator->insert(
        'Socialtext::Job::Test',
        { 
            message => 'no pun intended',
            sleep => 4,
            post_message => 'twss',
        },
    );

    fast_forward();
    get_more_lines_until(qr/no pun intended/);

    # Now send the process SIGTERM, and it should start to exit
    ok kill(TERM => $ceq_pid), "sent TERM to $ceq_pid";

    my @shutdown = get_more_lines_until(qr/master: exiting/);
    ok(grep(qr/caught SIGTERM/, @shutdown), 'see SIGTERM');
    ok(grep(qr/waiting for children to exit/, @shutdown), 'see "waiting"');
    ok(grep(qr/twss/, @shutdown), 'job got to finish, though');
}

Workers_are_limited: {
    Socialtext::JobCreator->insert(
        'Socialtext::Job::Test',
        { 
            message => "start-$_",
            sleep => 5,
            post_message => "end-$_",
        },
    ) for (0 .. 9);

    fast_forward();
    my $ceq_pid = ceq_start();

    # let some jobs start up
    sleep 3;

    # Now send the process SIGTERM, and it should start to exit
    ok kill(INT => $ceq_pid), "sent INT to $ceq_pid";

    my @lines = get_more_lines_until(qr/master: exiting/);

    my @started = sort {$a<=>$b} map { /start-(\d)/ ? $1 : () } @lines;
    my @ended =   sort {$a<=>$b} map { /end-(\d)/   ? $1 : () } @lines;

    is scalar(@started), 2, 'just two jobs got to start';
    is scalar(@ended), 2, 'just two jobs got to end';
    is_deeply \@started, \@ended, "same jobs got started and ran to completion";
}

# failsafe:
END {
    my $ceq_pid = qx($Ceq_bin --pid);
    chomp $ceq_pid;
    if ($ceq_pid) {
        diag "CLEANUP: killing ceqlotron" if NOISY;
        kill(9 => -$ceq_pid);
    }
}

sub ceq_start {
    system($Ceq_bin); # should start & daemonize
    sleep 1;
    my $ceq_pid = qx($Ceq_bin --pid);
    chomp $ceq_pid;
    ok $ceq_pid, 'ceqlotron started up';
    return $ceq_pid;
}

sub fast_forward {
    while( $nlwlog->read_line ) { }
}

sub get_more_lines_until {
    my $cond_re = shift;
    my $tries = 7;
    my @lines;
    while ($tries-- > 0) {
        my $got_cond = 0;

        # keep reading until there's nothing left
        while (my $line = $nlwlog->read_line) {
            chomp $line;
            diag "LOG: $line" if NOISY;
            push @lines, $line;
            $got_cond = 1 if $line =~ $cond_re;
        }

        last if $got_cond;

        diag 'waiting for more lines...' if NOISY;
        sleep 1;
    }
    ok scalar(@lines), 'got more lines';
    return @lines;
}

exit;

