#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 8;
use Test::Socialtext;
use Test::Exception;
fixtures(qw(plugin));

my $hub = create_test_hub;
my $workspace1 = $hub->current_workspace;
my $workspace2 = create_test_workspace(user => $hub->current_user);

$workspace1->enable_plugin('prefsetter');
$workspace2->enable_plugin('prefsetter');
$workspace1->enable_plugin('other');
$workspace2->enable_plugin('other');

my $plugin = Socialtext::Pluggable::Plugin::Prefsetter->new;
$plugin->hub($hub);

# Get/Set
{
    $hub->current_workspace($workspace1);

    lives_ok {
        $plugin->set_workspace_prefs(
            number => 43,
            string => 'hi',
        );
    } "set_workspace_prefs";

    is_deeply $plugin->get_workspace_prefs,
              { number => 43, string => 'hi' },
              'get_workspace_prefs';

    lives_ok {
        $plugin->set_workspace_prefs(
            number => 44,
            other => 'ho',
        );
    } "set_workspace_prefs with a subset";

    is_deeply $plugin->get_workspace_prefs,
              { number => 44, string => 'hi', other => 'ho' },
              'get_workspace_prefs';
}

# settings are workspace scoped
{
    $hub->current_workspace($workspace2);
    lives_ok { $plugin->set_workspace_prefs(number => 32) }
             "set_workspace_prefs(number => SCALAR)";
    is_deeply $plugin->get_workspace_prefs,
              { number => 32 },
              "prefs are workspace scoped";
}

# No workspace
{
    $hub->current_workspace(undef);

    dies_ok { $plugin->get_workspace_prefs } "workspace is required"
}

# Plugin scope
{
    my $other_plugin = Socialtext::Pluggable::Plugin::Other->new;
    $other_plugin->hub($hub);
    $hub->current_workspace($workspace1);

    is_deeply $other_plugin->get_workspace_prefs, {},
        "prefs are plugin scoped";
}

package Socialtext::Pluggable::Plugin::Prefsetter;
use base 'Socialtext::Pluggable::Plugin';
sub scope { 'workspace' }

package Socialtext::Pluggable::Plugin::Other;
use base 'Socialtext::Pluggable::Plugin';
sub scope { 'workspace' }
