package Socialtext::TheSchwartz;
use Moose;
use Socialtext::SQL qw/sql_execute get_dbh/;
use TheSchwartz::Moosified;
use namespace::clean -except => 'meta';

extends qw/TheSchwartz::Moosified/;

has '+verbose' => ( default => ($ENV{ST_JOBS_VERBOSE} ? 1 : 0) );

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

sub Unlimit_list_jobs {
    no warnings 'once';
    $TheSchwartz::Moosified::FIND_JOB_BATCH_SIZE = 0xFFFFFFFF;
}

sub stat_jobs {
    my $self = shift;
    my $fold = shift;
    $fold = 1 unless defined $fold;
    
    my @results = map {
        $self->_stat_jobs_per_dbh($_)
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
            COALESCE(grabbed, 0) AS grabbed
        FROM funcmap
        LEFT JOIN (
            SELECT funcid,
                COUNT(jobid) AS queued,
                COUNT(NULLIF(run_after > $1, 'f'::boolean)) AS delayed,
                COUNT(NULLIF(grabbed_until > $1, 'f'::boolean)) AS grabbed
            FROM job
            GROUP BY funcid
        ) s USING (funcid)
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

__PACKAGE__->meta->make_immutable;
1;
