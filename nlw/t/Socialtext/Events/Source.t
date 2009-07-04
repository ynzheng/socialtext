#!perl
# @COPYRIGHT@
use warnings;
use strict;
use Test::More tests => 89;
use mocked 'Socialtext::User';

BEGIN {
    use_ok 'Socialtext::Events::Event';
    use_ok 'Socialtext::Events::Source';
    use_ok 'Socialtext::Events::Stream';
}

{
    package Socialtext::Events::Stream::Test;
    use Moose;
    extends 'Socialtext::Events::Stream';

    after 'add_sources' => sub {
        my $self = shift;
        my $sources = shift;

        for my $feed (2,1,3) {
            my $src = $self->construct_source(
                'Socialtext::Events::Source::Example' => 
                id => $feed,
                _events => [
                    [1_234_567_894 . ".0000$feed" + 0.0, {feed=>$feed,nr=>4}],
                    [1_234_567_893 . ".0000$feed" + 0.0, {feed=>$feed,nr=>3}],
                    [1_234_567_892 . ".0000$feed" + 0.0, {feed=>$feed,nr=>2}],
                    [1_234_567_891 . ".0000$feed" + 0.0, {feed=>$feed,nr=>1}],
                ]
            );
            push @$sources, $src;
        }
        push @$sources, $self->construct_source(
            'Socialtext::Events::EmptySource'
        );
    };

    has '+filter' => (
        default => sub { Socialtext::Events::FilterParams->new }
    );

    package Socialtext::Events::Event::Test;
    use Moose;
    extends 'Socialtext::Events::Event';
    has 'feed' => (is => 'rw', isa => 'Str', required => 1);
    has 'nr' => (is => 'rw', isa => 'Str', required => 1);

    after 'build_hash' => sub {
        my $self = shift;
        my $hash = shift;
        $hash->{test} = $self->feed.'-'.$self->nr;
    };

    package Socialtext::Events::Source::Example;
    use Moose;
    with 'Socialtext::Events::Source';

    has 'id' => (is => 'ro', isa => 'Str');
    has '_events' => (is => 'ro', isa => 'ArrayRef', required => 1);

    sub prepare {
        my $self = shift;
        my $evs = $self->_events;
        my $before = $self->filter->before || 0x7fffffff;
        my $after = $self->filter->after || 0;
        @$evs = grep { 
            $_->[0] > $after && $_->[0] < $before
        } @$evs;

        return @$evs > 0;
    }

    sub peek {
        my $self = shift;
        return unless @{$self->_events};
        my $head = $self->_events->[0];
        return unless $head;
        return $head->[0];
    }

    sub next {
        my $self = shift;
        my $head = shift @{ $self->_events };
        return unless $head;
        return Socialtext::Events::Event::Test->new(
            at_epoch => $head->[0],
            at => $head->[0],
            actor_id => 1,
            action => 'test',
            %{$head->[1]}
        );
    }

    sub skip {
        my $self = shift;
        shift @{ $self->_events };
        return;
    }
}

Happy_path: {
    my $stream = Socialtext::Events::Stream::Test->new(
        viewer => Socialtext::User->new(user_id => 111),
    );
    isa_ok $stream => 'Socialtext::Events::Stream::Test';
    ok $stream->prepare();

    ok $stream->peek;

    for my $ex_nr (4,3,2,1) {
        for my $ex_feed (3,2,1) {
            my $ev = $stream->next;
            isa_ok $ev => 'Socialtext::Events::Event';
            is $ev->feed, $ex_feed;
            is $ev->nr, $ex_nr;
        }
    }

    is $stream->peek, undef;
    ok !defined($stream->next), 'end of stream';
}

Limit: {
    my $stream = Socialtext::Events::Stream::Test->new(
        viewer => Socialtext::User->new(user_id => 111),
        limit => 4,
    );
    isa_ok $stream => 'Socialtext::Events::Stream::Test';
    ok $stream->prepare();

    $stream->skip for (1..3);

    my $ev = $stream->next;
    is $ev->feed, 3;
    is $ev->nr, 3;

    ok !defined($stream->next), 'end of stream';
}

Limit_and_offset: {
    my $stream = Socialtext::Events::Stream::Test->new(
        viewer => Socialtext::User->new(user_id => 111),
        limit => 4,
        offset => 4,
    );
    isa_ok $stream => 'Socialtext::Events::Stream::Test';
    ok $stream->prepare();

    $stream->skip for (1 .. 3);

    my $t = $stream->peek;
    is $t, 1_234_567_892 . ".00002";
    my $ev = $stream->next;
    is $ev->feed, 2;
    is $ev->nr, 2;

    ok !defined($stream->next), 'end of stream';
}

Before: {
    my $stream = Socialtext::Events::Stream::Test->new(
        viewer => Socialtext::User->new(user_id => 111),
        filter => Socialtext::Events::FilterParams->new(
            before => 1_234_567_892,
        )
    );
    isa_ok $stream => 'Socialtext::Events::Stream::Test';
    ok $stream->prepare();

    my $ev = $stream->next;
    is $ev->feed, 3;
    is $ev->nr, 1;

    $ev = $stream->next;
    is $ev->feed, 2;
    is $ev->nr, 1;

    $ev = $stream->next;
    is $ev->feed, 1;
    is $ev->nr, 1;

    ok !defined($stream->next), 'end of stream';
}

Before_and_after: {
    my $stream = Socialtext::Events::Stream::Test->new(
        viewer => Socialtext::User->new(user_id => 111),
        filter => Socialtext::Events::FilterParams->new(
            before => 1_234_567_894,
            after => 1_234_567_893,
        )
    );
    isa_ok $stream => 'Socialtext::Events::Stream::Test';
    $stream->assemble();
    ok $stream->prepare();

    my $ev = $stream->next;
    is $ev->feed, 3;
    is $ev->nr, 3;

    $ev = $stream->next;
    is $ev->feed, 2;
    is $ev->nr, 3;

    $ev = $stream->next;
    is $ev->feed, 1;
    is $ev->nr, 3;

    ok !defined($stream->next), 'end of stream';
}

All: {
    my $stream = Socialtext::Events::Stream::Test->new(
        viewer => Socialtext::User->new(user_id => 111),
        filter => Socialtext::Events::FilterParams->new(
            before => 1_234_567_892,
        )
    );
    isa_ok $stream => 'Socialtext::Events::Stream::Test';
    ok $stream->prepare();
    my $all = $stream->all();
    ok ref($all) eq 'ARRAY', 'got the whole array';
    isa_ok $all->[0] => 'Socialtext::Events::Event::Test';

    my @got = map { [$_->feed,$_->nr] } @$all;
    is_deeply \@got, [ [3,1], [2,1], [1,1] ];

    ok !defined($stream->next), 'end of stream';
}

All_hashes: {
    my $stream = Socialtext::Events::Stream::Test->new(
        viewer => Socialtext::User->new(user_id => 111),
        filter => Socialtext::Events::FilterParams->new(
            before => 1_234_567_892,
        )
    );
    isa_ok $stream => 'Socialtext::Events::Stream::Test';
    ok $stream->prepare();
    my $all = $stream->all_hashes();
    ok ref($all) eq 'ARRAY', 'got the whole array';
    ok !Scalar::Util::blessed($all->[0]), 'elements aren\'t references';

    my @got = map { $_->{test} } @$all;
    is_deeply \@got, [ "3-1", "2-1", "1-1" ];

    ok !defined($stream->next), 'end of stream';
}

Empty: {
    my $stream = Socialtext::Events::Stream::Test->new(
        viewer => Socialtext::User->new(user_id => 111),
        filter => Socialtext::Events::FilterParams->new(
            before => 100,
        )
    );
    isa_ok $stream => 'Socialtext::Events::Stream::Test';
    ok !$stream->prepare();
    my $all = $stream->all();
    ok ref($all) eq 'ARRAY', 'got the whole array';
    is scalar(@$all), 0, 'empty array';
}
