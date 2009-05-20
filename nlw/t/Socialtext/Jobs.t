#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext tests => 44;
use Test::Exception;
use Socialtext::SQL qw/:exec get_dbh/;

fixtures('db', 'foobar');

BEGIN {
    use_ok 'Socialtext::Jobs';
    use_ok 'Socialtext::JobCreator';
}

my $foobar = Socialtext::Workspace->new(name => 'foobar');
ok $foobar, "loaded foobar workspace";

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

    sleep 1;
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

Process_a_failing_cmd_job: {
    $jobs->clear_jobs();

    use_ok 'Socialtext::Job::Cmd';

    my $handle = Socialtext::JobCreator->insert('Socialtext::Job::Cmd', cmd => '/bin/false');;
    is scalar($jobs->list_jobs( funcname => 'Socialtext::Job::Cmd' )), 1;
   
    $jobs->can_do('Socialtext::Job::Cmd');
    $jobs->work_once();

    my @failures = $handle->failure_log;
    is scalar(@failures), 1;
    is $failures[0], "rc=256";
    is $handle->exit_status, 256, 'correct exit status';
}

Workspace_does_not_exist: {
    $jobs->clear_jobs();
    local $Socialtext::Job::Test::Retries = 2;

    my $handle = Socialtext::JobCreator->insert('Socialtext::Job::Test' => {
        workspace_id => -2,
        get_workspace => 1,
    });

    $jobs->can_do('Socialtext::Job::Test');
    $jobs->work_once();

    # check for permanent failure
    my @failures = $handle->failure_log;
    is scalar(@failures), 1, "one failure";
    like $failures[0], qr/workspace id=-2 no longer exists/i, "builder failed";
    is $handle->exit_status, 1, "has an exit_status";

    my @jobs = Socialtext::Jobs->list_jobs(
        funcname => 'Socialtext::Job::Test',
    );
    is scalar(@jobs), 0, 'perma-fail: no jobs left';
}

Page_does_not_exist: {
    $jobs->clear_jobs();
    local $Socialtext::Job::Test::Retries = 1;

    my $handle = Socialtext::JobCreator->insert('Socialtext::Job::Test' => {
        workspace_id => $foobar->workspace_id,
        page_id => 'does_not_exist',
        get_page => 1,
    });

    $jobs->can_do('Socialtext::Job::Test');
    $jobs->work_once();
    {
        my @failures = $handle->failure_log;
        is scalar(@failures), 1, "one failure";
        like $failures[0], qr/Couldn't load page id=does_not_exist/i;
        ok !$handle->exit_status, "job will be retried";

        my @jobs = Socialtext::Jobs->list_jobs(
            funcname => 'Socialtext::Job::Test',
        );
        is scalar(@jobs), 1, "not a perma-fail yet";
    }

    $jobs->can_do('Socialtext::Job::Test');
    $jobs->work_once();
    {
        my @failures = $handle->failure_log;
        is scalar(@failures), 2, "two failures";
        like $failures[0], qr/Couldn't load page id=does_not_exist/i;
        like $failures[1], qr/Couldn't load page id=does_not_exist/i;
        ok $handle->exit_status, "job has failed permanently now";

        my @jobs = Socialtext::Jobs->list_jobs(
            funcname => 'Socialtext::Job::Test',
        );
        is scalar(@jobs), 0, 'perma-fail: no jobs left';
    }
}

Indexer_fails_to_instantiate: {
    $jobs->clear_jobs();

    my $handle = Socialtext::JobCreator->insert('Socialtext::Job::Test' => {
        workspace_id => $foobar->workspace_id,
        get_workspace => 1,
        page_id => 'foobar_wiki',
        get_page => 1,
        search_config => 'OMGBARF',
        get_indexer => 1,
    });

    $jobs->can_do('Socialtext::Job::Test');
    $jobs->work_once();
    {
        my @failures = $handle->failure_log;
        is scalar(@failures), 1, "one failure";
        like $failures[0], qr/Couldn't create an indexer:/, 'indexer fail';
        ok $handle->exit_status, "job exited";
    }
}
