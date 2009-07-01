#!perl
use warnings;
use strict;
use Test::More tests => 14;
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


    sub query_and_binds {
        my $self = shift;

        my @where = (
            \"junk",
            -nest => $self->filter->generate_filter(
                qw(before after actor_id person_id tag_name)
            ),
        );

        my $sa = sql_abstract();
        my ($sql, @binds) = $sa->select(
            'event_page_contrib', '*', \@where, 'at DESC', $self->limit);

        return $sql, \@binds;
    }

    sub next {
        Socialtext::Events::Event->new(shift->next_sql_result);
    }
}

Exercise_params: {
    my $filter = Socialtext::Events::FilterParams->new();
    isa_ok $filter => 'Socialtext::Events::FilterParams';

    for my $illegal (qw(followed following contribs)) {
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
        filter => $filter,
        limit => 5,
    );

    lives_ok { $source->_build_sql_results };
    sql_ok(
        name => 'verbose generation',
        args => [54321, 12345, 27, 'sqeak', 'squak'],
        sql => q{
            SELECT * FROM event_page_contrib
            WHERE ( (
                junk
                AND (
                    at < 'epoch'::timestamptz + ? * '1 second'::interval
                    AND 
                    at > 'epoch'::timestamptz + ? * '1 second'::interval
                    AND actor_id = ?
                    AND person_id IS NULL
                    AND tag_name IN ( ?, ? )
                )
            ) )
            ORDER BY at DESC
            LIMIT 5
        },
    );
    ok_no_more_sql();
}
