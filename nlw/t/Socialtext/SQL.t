#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Exception;
use Test::Socialtext tests => 15;

# Fixtures: db
#
# Want Pg running, but don't care what's in it.
fixtures( 'db' );

BEGIN {
    use_ok 'Socialtext::Schema';
    use_ok 'Socialtext::SQL', qw( 
        sql_execute sql_execute_array
        sql_convert_to_boolean sql_convert_from_boolean 
    );
}

sql_execute: {
    my $sth;
    sql_execute('CREATE TABLE foo (name text)');
    $sth = sql_execute('SELECT * FROM foo');
    is_deeply $sth->fetchall_arrayref, [], 'no data found in table';

    sql_execute(q{INSERT INTO foo VALUES ('luke')});
    $sth = sql_execute('SELECT * FROM foo');
    is_deeply $sth->fetchall_arrayref, [ ['luke' ] ], 'data found in table';

    { 
        local $SIG{__WARN__} = sub { };
        sql_execute('DROP TABLE foo');
        eval { sql_execute('SELECT * FROM foo') };
        ok $@, "table was deleted";
    }
}

sql_execute_array: {
    my $sth;
    sql_execute('CREATE TABLE bar (name text, value text)');

    sql_execute_array(
        q{INSERT INTO bar VALUES (?,?)},
        {},
        [ map { "name $_" } 0 .. 10 ],
        [ map { "value $_" } 0 .. 10 ],
    );
    $sth = sql_execute('SELECT * FROM bar');
    is_deeply $sth->fetchall_arrayref, [ 
        map { ["name $_", "value $_"] } 0 .. 10 
    ], 'data found in table';

    { 
        local $SIG{__WARN__} = sub { };
        sql_execute('DROP TABLE bar');
        eval { sql_execute('SELECT * FROM bar') };
        ok $@, "table was deleted";
    }
}

sql_execute_array_errors: {
    sql_execute('CREATE TABLE parent (id integer)');
    sql_execute(
        'ALTER TABLE parent ADD CONSTRAINT parent_id_pk PRIMARY KEY (id)'
    );
    sql_execute('CREATE TABLE child (id integer, dad integer)');
    sql_execute('
        ALTER TABLE child ADD CONSTRAINT parent_id_fk
         FOREIGN KEY (dad) REFERENCES parent(id)
    ');

    sql_execute_array('INSERT INTO parent values (?)', {}, [1,2,3,4,5]);
    dies_ok {
        sql_execute_array(
            'INSERT INTO child values (?, ?)', {},
            [1,2,3,4,5], [1,2,3,7,5],
        );
    } "foreign key constraint violation";
    like $@, qr{violates foreign key constraint "parent_id_fk"},
         "Eror is propogated";
}

Transactions: {
    ok 1;
}

SQL_CONVERT_TO_BOOLEAN: {
    my $value = 0;
    my $sql_value = sql_convert_to_boolean($value,'t');
    is($sql_value, 'f', 'false if f');

    $value = 1;
    $sql_value = sql_convert_to_boolean($value,'f');
    is($sql_value, 't', 'true if t');

    $value = undef;
    $sql_value = sql_convert_to_boolean($value,'t');
    is($sql_value, 't', 'default works');
}

SQL_CONVERT_FROM_BOOLEAN: {
    my $sql_value = 't';
    my $value = sql_convert_from_boolean($sql_value);
    is($value, 1, 'true is 1');

    $sql_value = 'f';
    $value = sql_convert_from_boolean($sql_value);
    is($value, 0, 'false is 0');
}
