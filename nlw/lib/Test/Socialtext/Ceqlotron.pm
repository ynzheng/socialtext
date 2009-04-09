package Test::Socialtext::Ceqlotron;
# @COPYRIGHT@
use strict;
use warnings;
use Test::Builder ();
use File::LogReader;
use Socialtext::AppConfig;
use base 'Exporter';
our $VERSION = 1.0;
our @EXPORT = qw(ceq_config ceq_bin ceq_start ceq_kill
                 ceq_fast_forward ceq_get_log_until);

use constant NOISY => 0; # turn this on for diag()

our $Ceq_bin = 'bin/ceqlotron';
our $NLW_log_file = 't/tmp/log/nlw.log';
system("touch $NLW_log_file");
my $nlwlog;

sub ceq_config {
    my %args = @_;
    while (my ($k,$v) = each %args) {
        my $config = "ceqlotron_$k";
        system("st-config set $config $v > /dev/null")
            and die "unable to set $k";
    }
}

sub ceq_bin { $Ceq_bin }

sub ceq_start {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $args = shift || '';
    system("$Ceq_bin $args");
    return if ($args =~ /(?:--foreground|-f)/);

    sleep 1;

    my $ceq_pid = `$Ceq_bin --pid`;
    chomp $ceq_pid;
    Test::Builder->new->ok($ceq_pid, 'ceqlotron started up');
    return $ceq_pid;
}

sub nlwlog {
    $nlwlog ||= File::LogReader->new( filename => $NLW_log_file );
    return $nlwlog;
}

sub ceq_fast_forward {
    while( nlwlog()->read_line ) { }
}

sub ceq_get_log_until {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $cond_re = shift;
    my $tries = 7;
    my @lines;

    while ($tries-- > 0) {
        my $got_cond = 0;

        # keep reading until there's nothing left
        while (my $line = nlwlog()->read_line) {
            chomp $line;
            Test::Builder->new->diag("LOG: $line") if NOISY;
            push @lines, $line;
            $got_cond = 1 if $line =~ $cond_re;
        }

        last if $got_cond;

        Test::Builder->new->diag('waiting for more lines...') if NOISY;
        sleep 1;
    }
    Test::Builder->new->ok(scalar(@lines), 'got more lines');
    return @lines;
}

sub ceq_kill {
    my $ceq_pid = qx($Ceq_bin --pid);
    chomp $ceq_pid;
    if ($ceq_pid) {
        Test::Builder->new->diag("CLEANUP: killing ceqlotron") if NOISY;
        kill(9 => -$ceq_pid);
    }
}

1;
