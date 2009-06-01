package Test::Socialtext::Group;
# @COPYRIGHT@

use strict;
use warnings;

sub delete_recklessly {
    my $class = shift;
    my $group = shift;

    require Socialtext::SQL;

    Socialtext::SQL::sql_execute(q{
        DELETE FROM user_group_role
         WHERE group_id = ?
    }, $group->group_id);

    Socialtext::SQL::sql_execute(q{
        DELETE FROM groups
         WHERE group_id = ?
    }, $group->group_id);
}

1;
