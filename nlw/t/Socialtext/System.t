#!perl
# @COPYRIGHT@
use warnings;
use strict;
use Test::More tests => 23;
use Test::Exception;
use Socialtext::System;
use Socialtext::File qw/set_contents/;

my $in = "obase=16\n912559\n65261\n";
my $expected = "DECAF\nFEED\n";

Backtick: {
    my $out;
    $out = backtick("uggle");
    like($@, qr{uggle.*not found}, 'backtick admits when the command isn\'t found');
    ok !$out;

    $out = backtick(qw(cat /asdf/asdf/asd/f/asdf/));
    like($@, qr{asdf/: No such file}, 'backtick should die on command failures');
    ok !$out;

    my $temp = "t/run.t-$$";
    set_contents($temp, $in);
    lives_ok { $out = backtick('bc', $temp) };
    unlink $temp or die "Can't unlink $temp: $!";

    is($@, '', 'backtick should not emit errors if nothing went wrong');
    is($out, $expected, 'backtick output correct');
}

Quote_args: {
    my @tests = (
        [[ 'foo' ]              => q{foo} ],
        [[ 'foo bar' ]          => q{"foo bar"} ],
        [[ 'foo bar', 'baz' ]   => q{"foo bar" baz} ],
        [[ 'a', '', 'c' ]       => q{a "" c} ],
        [[ q{ab'cd"df$gh\\} ]    => q{ab\\'cd\\"df\\$gh\\\\} ],
    );
    for (@tests) {
        is quote_args(@{$_->[0]}), $_->[1], $_->[1];
    }
}

Run: {
    lives_ok { shell_run('/bin/date > /dev/null') };
    is $@, '', 'single arg';

    lives_ok { shell_run('-/bin/false') };
    is $@, '', 'prevented die';
}

Backticks_timeout: {
    my $out;
    $out = timeout_backtick(1 => qw(sleep 5));
    ok !$out;
    like $@, qr/Command Timeout/;
}

Backticks_vmem_limit: {
    local $Socialtext::System::VMEM_LIMIT = 100 * 2**20; # 100MiB

    my @mem_bomb = ('perl','-e','sleep 2; while(1){ push @x,"asdf" x 1024 }');

    my $out;
    $out = backtick(@mem_bomb);

    ok !$out;
    ok $@;
    unlike $@, qr/Command Timeout/;

    Also_with_timeout: {
        local $Socialtext::System::TIMEOUT = 1;
        $out = backtick(@mem_bomb);
        ok !$out;
        like $@, qr/Command Timeout/;
    }
}
