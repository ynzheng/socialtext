package Socialtext::JSON::Proxy::Helper;
# @COPYRIGHT@
use strict;
use warnings;

use Socialtext::SQL qw(sql_execute);

sub ClearForUser {
    my ($class, $user_id) = @_;
    sql_execute('DELETE FROM json_proxy_cache WHERE user_id = ?', $user_id);
}

1;

__END__

=head1 NAME

Socialtext::JSON::Proxy::Helper

=head1 SYNOPSIS

Socialtext::JSON::Proxy::Helper->clear_for_user($user_id)

=head1 DESCRIPTION

Socialtext::JSON::Proxy uses Mouse. Therefore, within NLW, this module should be used for holding all utility functions for accessing or clearing the JSON Proxy.

=cut
