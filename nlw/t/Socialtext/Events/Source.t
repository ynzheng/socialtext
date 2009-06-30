
use Test::More qw/no_plan/;
use mocked 'Socialtext::User';

BEGIN {
    use_ok 'Socialtext::Events::Event';
    use_ok 'Socialtext::Events::Source';
    use_ok 'Socialtext::Events::Stream';
}

{

    package Socialtext::Events::Stream::Test;
    use Moose;
    with 'Socialtext::Events::Stream';

    sub _build_sources {
        my $self = shift;
        my @sources;
        for my $feed (2,1,3) {
            my $src = $self->construct_source(
                'Socialtext::Events::Source::Test' => 
                _events => [
                    [1_234_567_894 . ".0000$feed" + 0.0, {feed=>$feed,nr=>4}],
                    [1_234_567_893 . ".0000$feed" + 0.0, {feed=>$feed,nr=>3}],
                    [1_234_567_892 . ".0000$feed" + 0.0, {feed=>$feed,nr=>2}],
                    [1_234_567_891 . ".0000$feed" + 0.0, {feed=>$feed,nr=>1}],
                ]
            );
            push @sources, $src;
        }
        return \@sources;
    }

    package Socialtext::Events::Event::Test;
    use Moose;
    extends 'Socialtext::Events::Event';
    has 'feed' => (is => 'rw', isa => 'Str');
    has 'nr' => (is => 'rw', isa => 'Str');

    package Socialtext::Events::Source::Test;
    use Moose;
    with 'Socialtext::Events::Source';

    has '_events' => (is => 'ro', isa => 'ArrayRef', required => 1);

    sub prepare {
        my $self = shift;
        my $evs = $self->_events;
        @$evs = grep { 
            $_->[0] > $self->after && $_->[0] < $self->before
        } @$evs;
    }

    sub peek {
        my $self = shift;
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
    $stream->prepare();

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
    $stream->prepare();

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
    $stream->prepare();

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
        before => 1_234_567_892,
    );
    isa_ok $stream => 'Socialtext::Events::Stream::Test';
    $stream->prepare();

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
