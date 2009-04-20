#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 10;
use Test::Socialtext;
use Socialtext::Account;
use Socialtext::User;
use Test::Exception;
fixtures(qw(plugin));

my $hub = create_test_hub;
my $user1 = create_test_user();
my $user2 = create_test_user();
$hub->current_user($user1);

my $plugin = Socialtext::Pluggable::Plugin::Prefsetter->new;
$plugin->hub($hub);

# Get/Set
{
    lives_ok {
        $plugin->set_user_prefs(
            number => 43,
            string => 'hi',
        );
    } "set_user_prefs";

    is_deeply $plugin->get_user_prefs,
              { number => 43, string => 'hi' },
              'get_user_prefs';

    lives_ok {
        $plugin->set_user_prefs(
            number => 44,
            other => 'ho',
        );
    } "set_user_prefs with a subset";

    is_deeply $plugin->get_user_prefs,
              { number => 44, string => 'hi', other => 'ho' },
              'get_user_prefs';

}

# settings are user scoped
{
    lives_ok { $plugin->set_user_prefs(number => 38) }
             "set_user_prefs(number => SCALAR)";
    $hub->current_user($user2);
    lives_ok { $plugin->set_user_prefs(number => 32) }
             "set_user_prefs(number => SCALAR)";
    is_deeply $plugin->get_user_prefs,
              { number => 32 },
              "prefs are user scoped";
    $hub->current_user($user1);
    lives_ok { $plugin->set_user_prefs(number => 38) }
             "set_user_prefs(number => SCALAR)";
}

# No user
{
    $hub->current_user(undef);

    dies_ok { $plugin->get_user_prefs } "user is required"
}

# Plugin scope
{
    my $other_plugin = Socialtext::Pluggable::Plugin::Other->new;
    $other_plugin->hub($hub);
    $hub->current_user($user1);

    is_deeply $other_plugin->get_user_prefs, {},
        "prefs are plugin scoped";
}

package Socialtext::Pluggable::Plugin::Prefsetter;
use base 'Socialtext::Pluggable::Plugin';
sub scope { 'user' }

package Socialtext::Pluggable::Plugin::Other;
use base 'Socialtext::Pluggable::Plugin';
sub scope { 'user' }
