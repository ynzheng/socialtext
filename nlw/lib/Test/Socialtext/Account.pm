package Test::Socialtext::Account;
# @COPYRIGHT@

use strict;
use warnings;
use Carp qw(croak);
use Class::Field qw(const);

sub delete_recklessly {
    my ($class, $account) = @_;

    # Load classes on demand
    require Socialtext::SQL;
    require Socialtext::Account;

    # Null out parent_ids in gadgets referencing this account's gadgets
    Socialtext::SQL::sql_execute(q{
        UPDATE gadget_instance
           SET parent_instance_id = NULL
         WHERE parent_instance_id IN (
            SELECT gadget_instance_id
              FROM gadget_instance
             WHERE container_id IN (
                SELECT container_id
                  FROM container
                 WHERE account_id = ?
             )
         )
    }, $account->account_id);

    $account->delete;
}

1;
