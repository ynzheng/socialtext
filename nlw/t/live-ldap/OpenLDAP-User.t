#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use mocked 'Socialtext::Log', qw(:tests);
use Socialtext::LDAP;
use Socialtext::User::LDAP::Factory;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 30;
use Test::Deep;

###############################################################################
### BOOTSTRAP OPENLDAP; none of these tests modify any of the data in the
### directory, so we can run them all against a single OpenLDAP instance.
###############################################################################
my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';
my $rc = Socialtext::LDAP::Config->save($openldap->ldap_config());
ok $rc, 'saved LDAP config to YAML';

ok $openldap->add('t/test-data/ldap/base_dn.ldif'), 'added data; base_dn';
ok $openldap->add('t/test-data/ldap/people.ldif'), 'added data; people';

my $factory = Socialtext::User::LDAP::Factory->new();
isa_ok $factory, 'Socialtext::User::LDAP::Factory';

###############################################################################
# Instantiate known user against OpenLDAP directory, by "user_id"
instantiate_known_user_by_user_id: {
    # get the user out of OpenLDAP
    my $user = $factory->GetUser( user_id => 'cn=John Doe,dc=example,dc=com' );
    isa_ok $user, 'Socialtext::User::LDAP', 'instantiated via user_id';

    # verify that all fields were extracted properly
    is $user->user_id,          'cn=John Doe,dc=example,dc=com',    '... user_id';
    is $user->username,         'John Doe',                         '... username';
    is $user->first_name,       'John',                             '... first_name';
    is $user->last_name,        'Doe',                              '... last_name';
    is $user->email_address,    'john.doe@example.com',             '... mail';
}

###############################################################################
# Instantiate known user against OpenLDAP directory, by "username"
instantiate_known_user_by_username: {
    # get the user out of OpenLDAP
    my $user = $factory->GetUser( username => 'Jane Smith' );
    isa_ok $user, 'Socialtext::User::LDAP', 'instantiated via username';

    # verify that all fields were extracted properly
    is $user->user_id,          'cn=Jane Smith,dc=example,dc=com',  '... user_id';
    is $user->username,         'Jane Smith',                       '... username';
    is $user->first_name,       'Jane',                             '... first_name';
    is $user->last_name,        'Smith',                            '... last_name';
    is $user->email_address,    'jane.smith@example.com',           '... email_address';
}

###############################################################################
# Instantiate known user against OpenLDAP directory, by "email_address"
instantiate_known_user_by_email_address: {
    # get the user out of OpenLDAP
    my $user = $factory->GetUser( email_address => 'john.doe@example.com' );
    isa_ok $user, 'Socialtext::User::LDAP', 'instantiated via email_address';

    # verify that all fields were extracted properly
    is $user->user_id,          'cn=John Doe,dc=example,dc=com',    '... user_id';
    is $user->username,         'John Doe',                         '... username';
    is $user->first_name,       'John',                             '... first_name';
    is $user->last_name,        'Doe',                              '... last_name';
    is $user->email_address,    'john.doe@example.com',             '... email_address';
}

###############################################################################
# Instantiate missing user against OpenLDAP directory.
instantiation_missing_user: {
    clear_log();

    my $user = $factory->GetUser( username => 'User Does Not Exist' );
    ok !$user, 'cannot find missing user';

    logged_like 'debug', qr/unable to find user/, 'logged message; unable to find user';
}

###############################################################################
# XXX: Instantiate when multiple matches present.
#instantiate_multiple_matches: {
#}

###############################################################################
# Search; no results
search_no_results: {
    my @results = $factory->Search('does-not-exist-in-directory');
    ok !@results, 'search; no matches';
}

###############################################################################
# Search; single result
search_single_result: {
    my @results = $factory->Search('BUBBA');
    is scalar(@results), 1, 'search; single result';

    my @expect = (
        { driver_name       => $factory->driver_key(),
          email_address     => 'bubba.brain@example.com',
          name_and_email    => 'Bubba Brain <bubba.brain@example.com>',
        } );
    cmp_deeply \@results, \@expect, '... results match expectations';
}

###############################################################################
# Search; multiple results
search_multiple_results: {
    my @results = $factory->Search('example.com');
    is scalar(@results), 3, 'search; multiple results';

    my @expect = (
        { driver_name       => $factory->driver_key(),
          email_address     => 'john.doe@example.com',
          name_and_email    => 'John Doe <john.doe@example.com>',
        },
        { driver_name       => $factory->driver_key(),
          email_address     => 'jane.smith@example.com',
          name_and_email    => 'Jane Smith <jane.smith@example.com>',
        },
        { driver_name       => $factory->driver_key(),
          email_address     => 'bubba.brain@example.com',
          name_and_email    => 'Bubba Brain <bubba.brain@example.com>',
        } );
    cmp_deeply \@results, \@expect, '... results match expectations';
}
