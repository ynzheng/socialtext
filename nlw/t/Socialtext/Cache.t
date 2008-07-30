#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::More tests => 28;

use_ok 'Socialtext::Cache';

###############################################################################
# create a named cache
create_named_cache: {
    my $cache = Socialtext::Cache->cache('test');
    isa_ok $cache, $Socialtext::Cache::CacheClass;
}

###############################################################################
# create multiple named caches
create_multiple_caches: {
    my $c1 = Socialtext::Cache->cache('test');
    isa_ok $c1, $Socialtext::Cache::CacheClass;

    my $c2 = Socialtext::Cache->cache('test2');
    isa_ok $c2, $Socialtext::Cache::CacheClass;

    isnt $c1, $c2, 'caches are actually different objects';
}

###############################################################################
# clear a cache by its handle
clear_cache_by_handle: {
    my $cache = Socialtext::Cache->cache('test');
    isa_ok $cache, $Socialtext::Cache::CacheClass;

    # add some data to the cache
    $cache->set('foo', 'bar');
    my $count = scalar $cache->get_keys();
    is $count, 1, 'cache has stuff in it';
    is $cache->get('foo'), 'bar', '... and value can be queried';

    # clear the cache
    $cache->clear();
    $count = scalar $cache->get_keys();
    is $count, 0, 'cache is now empty';
    ok !defined $cache->get('foo'), '... and value is no longer there';
}

###############################################################################
# clear a cache by its name
clear_cache_by_name: {
    my $cache = Socialtext::Cache->cache('test');
    isa_ok $cache, $Socialtext::Cache::CacheClass;

    # add some data to the cache
    $cache->set('foo', 'bar');
    my $count = scalar $cache->get_keys();
    is $count, 1, 'cache has stuff in it';
    is $cache->get('foo'), 'bar', '... and value can be queried';

    # clear the cache
    Socialtext::Cache->clear('test');
    $count = scalar $cache->get_keys();
    is $count, 0, 'cache is now empty';
    ok !defined $cache->get('foo'), '... and value is no longer there';
}

###############################################################################
# clear *all* named caches
clear_all_named_caches: {
    my $c1 = Socialtext::Cache->cache('test');
    isa_ok $c1, $Socialtext::Cache::CacheClass;

    my $c2 = Socialtext::Cache->cache('test2');
    isa_ok $c2, $Socialtext::Cache::CacheClass;

    # add some data to the caches
    $c1->set('foo', 'bar');
    my $count = scalar $c1->get_keys();
    is $count, 1, 'first cache has stuff in it';

    $c2->set('abc', '123');
    $count = scalar $c2->get_keys();
    is $count, 1, 'second cache has stuff in it';

    # clear the caches
    Socialtext::Cache->clear();
    $count = scalar $c1->get_keys();
    is $count, 0, 'first cache now empty';

    $count = scalar $c2->get_keys();
    is $count, 0, 'second cache now empty';
}

###############################################################################
# get list of named caches
list_named_caches: {
    my $c1 = Socialtext::Cache->cache('first');
    isa_ok $c1, $Socialtext::Cache::CacheClass;

    my $c2 = Socialtext::Cache->cache('second');
    isa_ok $c2, $Socialtext::Cache::CacheClass;

    my $c3 = Socialtext::Cache->cache('third');
    isa_ok $c3, $Socialtext::Cache::CacheClass;

    # add some data to the caches
    $c1->set( 'foo', 'bar' );
    $c2->set( 'abc', '123' );

    # the list of named caches should contain the caches we've added data to
    # above, and shouldn't contain the one that had any data.
    my @names = sort Socialtext::Cache->names();
    ok @names, 'retrieved list of named caches';
    ok  grep( { $_ eq 'first' } @names ),  '... containing the "first" cache with data in it';
    ok  grep( { $_ eq 'second' } @names ), '... containing the "second" cache with data in it';
    ok !grep( { $_ eq 'third' } @names ),  '... but not containing the "third" empty cache';
}
