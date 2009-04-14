#!perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext tests => 24;

fixtures('db');

our $EXEC = 'bin/ceq-exec';
our $READ = 'bin/ceq-read';
our $RM   = 'bin/ceq-rm';

sub make_exec_job {
    my $n = shift;
    my $exec_create = `$EXEC /bin/touch t/tmp/touch-job-$^T-$n 2>&1`;
    chomp $exec_create;
    my ($id) = ($exec_create =~ qr/job id (\d+)/);
    ok $id, "created job $n";
    is $exec_create, "job id $id", "job $n is id $id";
    return $id;
}

my $exec1_id = make_exec_job(1);
my $exec2_id = make_exec_job(2);
my $exec3_id = make_exec_job(3);

{
    my $listing = `$READ 2>&1`;
    like $listing, qr{(?m:id=$exec1_id;type=Cmd;cmd=/bin/touch;args=t/tmp/touch-job-$^T-1$)}, "job 1 is listed";
    like $listing, qr{(?m:id=$exec2_id;type=Cmd;cmd=/bin/touch;args=t/tmp/touch-job-$^T-2$)}, "job 2 is listed";
    like $listing, qr{(?m:id=$exec3_id;type=Cmd;cmd=/bin/touch;args=t/tmp/touch-job-$^T-3$)}, "job 3 is listed";
}

dry_run_rm: {
    my $dry_run_rm = `$RM --dryrun $exec1_id 2>&1`;
    like $dry_run_rm, qr{(?m:would de-schedule event for.+?id=$exec1_id;type=Cmd)};
    unlike $dry_run_rm, qr{(?m:would de-schedule event for.+?id=(?!$exec1_id;))}, 'no extra jobs';

    my $listing = `$READ 2>&1`;
    like $listing, qr{(?m:id=$exec1_id;type=Cmd;cmd=/bin/touch;args=t/tmp/touch-job-$^T-1$)}, "job 1 is listed";
    like $listing, qr{(?m:id=$exec2_id;type=Cmd;cmd=/bin/touch;args=t/tmp/touch-job-$^T-2$)}, "job 2 is listed";
    like $listing, qr{(?m:id=$exec3_id;type=Cmd;cmd=/bin/touch;args=t/tmp/touch-job-$^T-3$)}, "job 3 is listed";
}

dry_run_rm_alt_id: {
    my $dry_run_rm = `$RM --dryrun id=$exec2_id 2>&1`;
    like $dry_run_rm, qr{would de-schedule event for.+?id=$exec2_id;type=Cmd};
    unlike $dry_run_rm, qr{(?m:would de-schedule event for.+?id=(?!$exec2_id;))}, 'no extra jobs';

    my $listing = `$READ 2>&1`;
    like $listing, qr{(?m:id=$exec1_id;type=Cmd;cmd=/bin/touch;args=t/tmp/touch-job-$^T-1$)}, "job 1 is listed";
    like $listing, qr{(?m:id=$exec2_id;type=Cmd;cmd=/bin/touch;args=t/tmp/touch-job-$^T-2$)}, "job 2 is listed";
    like $listing, qr{(?m:id=$exec3_id;type=Cmd;cmd=/bin/touch;args=t/tmp/touch-job-$^T-3$)}, "job 3 is listed";
}

actually_rm: {
    my $really_rm = `$RM --verbose $exec3_id 2>&1`;
    like $really_rm, qr{(?m:^de-scheduling event for .+ id=$exec3_id;type=Cmd;cmd=/bin/touch;args=t/tmp/touch-job-$^T-3$)};
    unlike $really_rm, qr{(?m:^de-scheduling event for .+ id=(?!$exec3_id))}, 'no extra deletions';

    my $listing = `$READ 2>&1`;
    like $listing, qr{(?m:id=$exec1_id;type=Cmd;cmd=/bin/touch;args=t/tmp/touch-job-$^T-1$)}, "job 1 is listed";
    like $listing, qr{(?m:id=$exec2_id;type=Cmd;cmd=/bin/touch;args=t/tmp/touch-job-$^T-2$)}, "job 2 is listed";
    unlike $listing, qr{(?m:id=$exec3_id;type=Cmd;cmd=/bin/touch;args=t/tmp/touch-job-$^T-3$)}, "job 3 is no longer listed";
}
