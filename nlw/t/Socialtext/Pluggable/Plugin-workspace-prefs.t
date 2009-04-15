#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 14;
use Test::Socialtext;
use Test::Exception;
fixtures(qw(plugin));

my $hub = create_test_hub;
my $workspace1 = create_test_workspace(user => $hub->current_user);
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

    lives_ok { $plugin->set_workspace_pref(number => 43) }
             "set_workspace_pref(number => SCALAR)";

    lives_ok { $plugin->set_workspace_pref(string => 'hi') }
             "set_workspace_pref(string => SCALAR)";

    dies_ok { $plugin->set_workspace_pref(array => [1,2,3,4]) }
            "set_workspace_pref(array => REF)";

    dies_ok { $plugin->set_workspace_pref(hash => { a => 'whoah, what?' }) }
            "set_workspace_pref(hash => REF)";

    is $plugin->get_workspace_pref('number'), 43, 'Get number';
    is $plugin->get_workspace_pref('string'), 'hi', 'Get string';
    is $plugin->get_workspace_pref('array'), undef, 'Get array is undef';
    is $plugin->get_workspace_pref('hash'), undef, 'Get hash is undef';
}

# settings are workspace scoped
{
    $hub->current_workspace($workspace2);
    lives_ok { $plugin->set_workspace_pref(number => 32) }
             "set_workspace_pref(number => SCALAR)";
    is $plugin->get_workspace_pref('number'), 32, 'Workspace scope';
    is $plugin->get_workspace_pref('string'), undef, 'Workspace scope';
}

# No workspace
{
    $hub->current_workspace(undef);

    dies_ok { $plugin->get_workspace_pref('number') } "No workspace scope";
}

# Plugin scope
{
    my $other_plugin = Socialtext::Pluggable::Plugin::Other->new;
    $other_plugin->hub($hub);
    $hub->current_workspace($workspace1);
    is $other_plugin->get_workspace_pref('number'), undef, "Plugin scope";
    is $other_plugin->get_workspace_pref('string'), undef, "Plugin scope";
}

package Socialtext::Pluggable::Plugin::Prefsetter;
use base 'Socialtext::Pluggable::Plugin';
sub scope { 'workspace' }

package Socialtext::Pluggable::Plugin::Other;
use base 'Socialtext::Pluggable::Plugin';
sub scope { 'workspace' }
