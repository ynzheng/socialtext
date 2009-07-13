# @COPYRIGHT@
package Socialtext::Rest::Version;
use warnings;
use strict;

use base 'Socialtext::Rest';
use Socialtext::JSON;
use Readonly;

# Starting from 1 onward, $API_VERSION should be a simple incrementing integer:
# 1: iteration-2008-06-27
# 2: iteration-2009-02-13 (release-3.4.0)
# 3: iteration-2009-02-27 (release-3.4.1)
# 4: iteration-2009-03-27 (release-3.5.1): in_reply_to, mentioned_users
# 5: iteration-2009-04-10 (release-3.5.2): recipient, desktop_* in accounts
# 6: iteration-2009-04-27 (release-3.5.3)
# 7: iteration-2009-05-22 (release-3.5.5): limit search results
# 8: iteration-2009-06-05 (release-3.5.6): spreadsheetin'
# 9: iteration-2009-07-17 (release-3.5.9): /data/events gets new html template and supports account_id
Readonly our $API_VERSION => 9;
Readonly our $MTIME       => ( stat(__FILE__) )[9];

sub allowed_methods {'GET, HEAD'}

sub make_getter {
    my ( $type, $representation ) = @_;
    my @headers = (
        type           => "$type; charset=UTF-8",
        -Last_Modified => __PACKAGE__->make_http_date($MTIME),
    );
    return sub {
        my ( $self, $rest ) = @_;
        $rest->header(@headers);
        return $representation;
    };
}

{
    no warnings 'once';

    *GET_text = make_getter( 'text/plain', $API_VERSION );
    *GET_json
        = make_getter( 'application/json', encode_json( [$API_VERSION] ) );
}

1;
