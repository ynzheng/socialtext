#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 8;

###############################################################################
# Fixtures: base_config
# - Need config files around, but don't care what's in them.
fixtures(qw( base_config ));

###############################################################################
# Implement some Group Factories that we can test with/against
package ReadWriteGroupFactory;
use Moose;
with 'Socialtext::Group::Factory';

sub can_update_store { 1 };
sub Create {
    my ($self, $proto_group) = @_;
}

package ReadOnlyGroupFactory;
use Moose;
with 'Socialtext::Group::Factory';

sub can_update_store { 0 };
sub Create {
    my ($self, $proto_group) = @_;
}

package main;

###############################################################################
# TEST: instantiation
instantiation: {
    my $factory = ReadWriteGroupFactory->new(driver_key => 'ReadWrite:123');
    isa_ok $factory, 'ReadWriteGroupFactory', 'Test Group Factory';

    is $factory->driver_key,  'ReadWrite:123', '... with driver_key';
    is $factory->driver_name, 'ReadWrite',     '... ... containing driver_name';
    is $factory->driver_id,   '123',           '... ... containing driver_id';
}

###############################################################################
# TEST: read-write group is updateable
read_write_group_is_updateable: {
    my $factory = ReadWriteGroupFactory->new(driver_key => 'ReadWrite:123');
    isa_ok $factory, 'ReadWriteGroupFactory', 'ReadWrite Test Group Factory';
    ok $factory->can_update_store(), '... is updateable';
}

###############################################################################
# TEST: read-only group is NOT updateable
read_only_group_is_not_updateable: {
    my $factory = ReadOnlyGroupFactory->new(driver_key => 'ReadOnly:123');
    isa_ok $factory, 'ReadOnlyGroupFactory', 'ReadOnly Test Group Factory';
    ok !$factory->can_update_store(), '... is NOT updateable';
}
