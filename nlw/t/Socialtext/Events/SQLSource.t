#!perl
use warnings;
use strict;
use Test::More tests => 12;
use Test::Exception;
use mocked 'Socialtext::SQL', qw/:test/;
use mocked 'Socialtext::User';

BEGIN {
    use_ok 'Socialtext::Events::Source';
    use_ok 'Socialtext::Events::SQLSource';
}

{
    package Socialtext::Events::SQLSource::Test;
    use Moose;
    use Socialtext::SQL::Builder qw/sql_abstract/;
    with 'Socialtext::Events::Source', 'Socialtext::Events::SQLSource';

    use constant event_type => 'Socialtext::Events::Event';

    sub query_and_binds {
        my $self = shift;

        my @where = (
            \"junk",
            -nest => $self->filter->generate_filter(
                qw(before after actor_id person_id tag_name)
            ),
            -or => [
                this => \["IN (?)", "this-arg"],
                that => \["IN (?)", "that-arg"],
            ],
        );

        my $sa = sql_abstract();
        my ($sql, @binds) = $sa->select(
            'event_page_contrib', '*', \@where, 'at DESC', $self->limit);

        return $sql, \@binds;
    }
}

Exercise_params: {
    my $filter = Socialtext::Events::FilterParams->new();
    isa_ok $filter => 'Socialtext::Events::FilterParams';

    for my $illegal (qw(followed contributions)) {
        ok $filter->can($illegal);
        throws_ok {
            $filter->generate_filter($illegal);
        } qr/param '$illegal' must be handled manually/;
    }

    throws_ok {
        $filter->generate_filter('blarf');
    } qr/unknown param/;
}

Happy_path: {
    my $filter = Socialtext::Events::FilterParams->new(
        actor_id => 27,
        tag_name => ['sqeak','squak'],
        person_id => undef,
        after => 12345,
        before => 54321,
    );
    my $viewer = Socialtext::User->new(user_id => 222);
    my $source = Socialtext::Events::SQLSource::Test->new(
        viewer => $viewer,
        limit => 5,
        filter => $filter,
    );

    sql_mock_row_count(0);
    lives_ok { $source->_build_sql_results };
    sql_ok(
        name => 'verbose generation',
        args => [54321, 12345, 27, 'sqeak', 'squak', 'this-arg','that-arg'],
        sql => q{
            SELECT * FROM event_page_contrib
            WHERE ( (
                junk
                AND (
                    at < ?::timestamptz
                    AND 
                    at > ?::timestamptz
                    AND actor_id = ?
                    AND person_id IS NULL
                    AND tag_name IN ( ?, ? )
                )
                AND (
                    this IN (?)
                    OR
                    that IN (?)
                )
            ) )
            ORDER BY at DESC
            LIMIT 5
        },
    );
    ok_no_more_sql();
}
