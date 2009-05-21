#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 5;

###############################################################################
# Fixtures: base_config
# - need config around, but don't care what's in it
fixtures(qw( base_config ));

use_ok 'Socialtext::Group';

###############################################################################
# TEST: default Group Factories
default_group_factories_configuration: {
    my $is_default = Socialtext::AppConfig->is_default('group_factories');
    ok $is_default, 'default group_factories configuration';

    my @drivers  = Socialtext::Group->Drivers();
    my @expected = (qw(Default));
    is_deeply \@drivers, \@expected, '... one configured Group Factory';
}

###############################################################################
# TEST: parsing configured Group Factories list
configured_group_factories: {
    my $configured = 'Dummy:123;Default';

    Socialtext::AppConfig->set('group_factories', $configured);
    my $factories = Socialtext::AppConfig->group_factories();
    is $factories, $configured, 'custom group_factories configuration';

    my @drivers  = Socialtext::Group->Drivers();
    my @expected = (qw(Dummy:123 Default));
    is_deeply \@drivers, \@expected, '... two configured Group Factories';
}
