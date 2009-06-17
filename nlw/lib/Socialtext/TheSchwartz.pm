package Socialtext::TheSchwartz;
# @COPYRIGHT@
use Moose;
use Socialtext::SQL qw/sql_execute get_dbh/;
use TheSchwartz::Moosified;
use namespace::clean -except => 'meta';

extends qw/TheSchwartz::Moosified/;

has '+verbose' => ( default => ($ENV{ST_JOBS_VERBOSE} ? 1 : 0) );
has '+error_length' => ( default => 0 ); # unlimited errors logged
has '+prioritize' => ( default => 1 );

# make sure to call get_dbh() every time, basically
override 'databases' => sub { return [ get_dbh() ] };

around 'list_jobs' => sub {
    my $orig = shift;
    my $self = shift;
    my $args = (@_==1) ? shift : {@_};
    return $self->$orig($args);
};

# TheSchwartz will remove one job type for each job it fetches b/c of some
# mySQL limitation.  Since we're Pg only, disable this.
override 'temporarily_remove_ability' => sub {};

around 'insert' => sub {
    my $code = shift;
    my $self = shift;

    my $job;
    if (ref($_[0]) && $_[0]->isa('TheSchwartz::Moosified::Job')) {
        $job = shift;
    }
    else {
        my $job_class = shift;
        my $args = shift;
        my $opts = delete $args->{job} || {};

        $job = TheSchwartz::Moosified::Job->new(
            %$opts,
            funcname => $job_class,
            arg => $args,
        );
    }

    return $self->$code($job);
};

sub Unlimit_list_jobs {
    $TheSchwartz::Moosified::FIND_JOB_BATCH_SIZE = 0x7FFFFFFF;
}
sub Limit_list_jobs {
    my $class = shift;
    $TheSchwartz::Moosified::FIND_JOB_BATCH_SIZE = shift;
}

sub stat_jobs {
    my $self = shift;
    my $fold = shift;
    $fold = 1 unless defined $fold;
    
    my $now = time;
    my @results = map {
        $self->_stat_jobs_per_dbh($_, $now)
    } @{$self->databases};

    return @results unless $fold;

    my %stats;

    for my $r (@results) {
        for my $name (keys %{$r->{stats}}) {
            $stats{$name} ||= {};
            while (my ($stat, $value) = each %{$r->{stats}{$name}}) {
                $stats{$name}{$stat} += $value;
            }
        }
    }

    return \%stats;
}

sub _stat_jobs_per_dbh {
    my $self = shift;
    my $dbh = shift;
    my $now = shift || time;

    my $sth = $dbh->prepare_cached(q{
        SELECT funcname,
            COALESCE(queued, 0) AS queued,
            COALESCE(delayed, 0) AS delayed,
            COALESCE(grabbed, 0) AS grabbed,
            COALESCE(num_ok, 0) AS num_ok,
            COALESCE(num_fail, 0) AS num_fail,
            COALESCE(last_ok, 0) AS last_ok,
            COALESCE(last_fail, 0) AS last_fail
        FROM funcmap
        LEFT JOIN (
            SELECT funcid,
                COUNT(jobid) AS queued,
                COUNT(NULLIF(run_after > $1, 'f'::boolean)) AS delayed,
                COUNT(NULLIF(grabbed_until > $1, 'f'::boolean)) AS grabbed
            FROM job
            GROUP BY funcid
        ) s USING (funcid)
        LEFT JOIN (
            SELECT funcid,
                COUNT(NULLIF(status = 0, 'f'::boolean)) AS num_ok,
                COUNT(NULLIF(status <> 0, 'f'::boolean)) AS num_fail,
                MAX(
                    CASE WHEN status = 0 THEN completion_time
                         ELSE 0
                    END
                ) AS last_ok,
                MAX(
                    CASE WHEN status <> 0 THEN completion_time
                         ELSE 0
                    END
                ) AS last_fail
            FROM exitstatus
            GROUP BY funcid
        ) e USING (funcid)
    });

    $sth->execute($now);

    my %stats;
    while (my $row = $sth->fetchrow_hashref()) {
        delete $row->{funcid};
        my $name = delete $row->{funcname};
        $stats{$name} = $row;
    }

    return { database => $dbh, stats => \%stats };
}

sub cancel_job {
    my $self = shift;
    my $args = @_==1 ? shift : {@_};

    die "must supply funcname and uniqkey"
        unless $args->{funcname} && $args->{uniqkey};

    for my $dbh (@{ $self->databases }) {
        my $unixtime = TheSchwartz::Moosified::Utils::sql_for_unixtime($dbh);

        my $funcid = $self->funcname_to_id($dbh, $args->{funcname});
        my $sth = $dbh->prepare(qq{
            SELECT jobid FROM job
            WHERE funcid = ?
              AND uniqkey = ? 
              AND grabbed_until <= $unixtime
        });
        $sth->execute($funcid, $args->{uniqkey});
        my ($jobid) = $sth->fetchrow_array;
        $sth->finish;

        $sth = $dbh->prepare(qq{
            UPDATE job
            SET grabbed_until = 2147483647
            WHERE jobid = ?
              AND grabbed_until <= $unixtime
        });
        $sth->execute($jobid);
        return unless $sth->rows == 1;

        TheSchwartz::Moosified::Utils::run_in_txn {
            $dbh->do("DELETE FROM job WHERE jobid = ?", {}, $jobid);
            $dbh->do("INSERT INTO exitstatus 
                      (jobid,funcid,status,completion_time,delete_after)
                      VALUES (?,?,0,$unixtime,$unixtime)", {}, $jobid,$funcid);
        } $dbh;
    }
}

sub move_jobs_by {
    my $self = shift;
    my $args = @_==1 ? shift : {@_};

    die "must supply funcname and uniqkey"
        unless $args->{funcname} && $args->{uniqkey};
    die "must supply a shift in seconds"
        unless $args->{seconds};

    for my $dbh (@{ $self->databases }) {
        my $unixtime = TheSchwartz::Moosified::Utils::sql_for_unixtime($dbh);

        my $funcid = $self->funcname_to_id($dbh, $args->{funcname});
        # change grabbed_until so it doesn't get accidentally grabbed
        # TODO: make this so it doesn't modify grabbed_until
        my $sth = $dbh->prepare(qq{
            UPDATE job
            SET run_after = run_after + ?,
                grabbed_until = grabbed_until - 1
            WHERE funcid = ?
              AND uniqkey = ? 
              AND grabbed_until <= $unixtime
        });
        $sth->execute($args->{seconds}, $funcid, $args->{uniqkey});
    }
}


__PACKAGE__->meta->make_immutable;
1;
