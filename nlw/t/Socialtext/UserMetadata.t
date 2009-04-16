#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 6;
fixtures(qw( clean db ));
use Socialtext::User;
use Socialtext::UserMetadata;

my ($user, $user2, $user3);

$user = Socialtext::User->create(
    username => 'devnull1@example.com',
    first_name => 'Devious', 
    last_name => 'Nullous',
    email_address => 'devnull1@example.com', 
    password => 'password'
);

# Test the UserMetadata object via the delegation from the User object

ok ( $user->dm_sends_email, "dm_sends_email defaults true");

$user->set_dm_sends_email(0);
ok ( !$user->dm_sends_email, "set_dm_sends_email sets false");

$user2 = Socialtext::User->new( username=> 'devnull1@example.com');
ok ( !$user2->dm_sends_email, "dm_sends_email saved false in db");

$user->set_dm_sends_email(1);
ok ( $user->dm_sends_email, "set_dm_sends_email sets true");

$user2 = Socialtext::User->new( username=> 'devnull1@example.com');
ok ( $user2->dm_sends_email, "dm_sends_email saved true in db");

$user3 = Socialtext::User->create(
    username => 'devnull3@example.com',
    first_name => 'Devious', 
    last_name => 'Nullous',
    email_address => 'devnull3@example.com', 
    password => 'password',
    dm_sends_email => '0'
);

ok ( !$user3->dm_sends_email, "dm_sends_email create param sets false");

