#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext tests => 22;
use Test::Exception;
use Socialtext::SQL qw/:exec get_dbh/;

fixtures 'db';

BEGIN {
    use_ok 'Socialtext::Jobs';
    use_ok 'Socialtext::JobCreator';
}

my $jobs = Socialtext::Jobs->instance;
lives_ok {
     $jobs->clear_jobs();
} "can clear jobs";

Load_jobs: {
    my @job_types = $jobs->job_types;
    my @test_jobs = grep { $_ eq 'Socialtext::Job::Test' } @job_types;
    ok @test_jobs == 1, "Test job available";
    ok !$INC{"Socialtext/Job/Test.pm"}, 'test module is *not* loaded';
    use_ok 'Socialtext::Job::Test';
    ok $INC{"Socialtext/Job/Test.pm"}, 'test module now loaded';
}

Queue_job: {

    my @jobs = Socialtext::Jobs->list_jobs(
        funcname => 'Socialtext::Job::Test',
    );
    is scalar(@jobs), 0, 'no jobs to start with';

    my @job_args = ('Socialtext::Job::Test' => {test => 1} );
    dies_ok {
        $jobs->insert(@job_args);
    } "can't create jobs directly";

    lives_ok {
        Socialtext::JobCreator->insert(@job_args);
    } "used the job creator interface";

    @jobs = $jobs->list_jobs({
        funcname => 'Socialtext::Job::Test',
    });
    is scalar(@jobs), 1, 'found a job';
    my $j = shift @jobs;
    is $j->funcname, 'Socialtext::Job::Test', 'funcname is correct';
}

Process_a_job: {
    $jobs->clear_jobs();
    $Socialtext::Job::Test::Work_count = 0;

    Socialtext::JobCreator->insert('Socialtext::Job::Test', test => 1);
    is scalar($jobs->list_jobs( funcname => 'Socialtext::Job::Test' )), 1;
    is $Socialtext::Job::Test::Work_count, 0;
   
    $jobs->can_do('Socialtext::Job::Test');
    $jobs->work_once();

    is scalar($jobs->list_jobs( funcname => 'Socialtext::Job::Test' )), 0;
    is $Socialtext::Job::Test::Work_count, 1;
}

Process_a_failing_job: {
    $jobs->clear_jobs();
    $Socialtext::Job::Test::Work_count = 0;
    {
        no warnings 'once'; $Socialtext::Job::Test::Retries = 1;
    }

    Socialtext::JobCreator->insert('Socialtext::Job::Test', fail => 1);
    is scalar($jobs->list_jobs( funcname => 'Socialtext::Job::Test' )), 1;
    is $Socialtext::Job::Test::Work_count, 0;
   
    $jobs->can_do('Socialtext::Job::Test');
    $jobs->work_once();

    my @jobs = $jobs->list_jobs( funcname => 'Socialtext::Job::Test', want_handle => 1 );
    is scalar(@jobs), 1;
    my @failures = $jobs[0]->failure_log;
    is scalar(@failures), 1;
    is $failures[0], "failed!\n";
    is $Socialtext::Job::Test::Work_count, 0;
}
