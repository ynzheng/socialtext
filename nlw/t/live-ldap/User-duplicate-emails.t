#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Socialtext::User;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 11;

###############################################################################
# FIXTURE: db
#
# Need to have Pg running, but it doesn't have to contain any data.
fixtures(qw( db ));

###############################################################################
# TEST: Resolving a User by e-mail address should find the LDAP record first
#
# This addresses Bug #2415 "User wafls render incorrect User, when duplicate
# Users exist".
resolve_user_by_email_finds_ldap_first: {
    my $email_address = 'john.doe@example.com';

    # create a Default user in the DB that is going to end up having the same
    # e-mail address as an LDAP User that we'll create momentarily.
    my $user = Socialtext::User->create(
        username        => $email_address,
        email_address   => $email_address,
        first_name      => 'Default',
        last_name       => 'User',
        password        => 'dummy-password',
    );
    isa_ok $user, 'Socialtext::User', 'new Default User';
    is $user->homunculus->driver_name, 'Default', '... using the Defaultuser factory';

    # bootstrap OpenLDAP, and populate it with users (including a User that
    # happens to match the e-mail address we used above).
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP';
    ok $openldap->add_ldif('t/test-data/ldap/base_dn.ldif'), 'added LDAP data; base_dn';
    ok $openldap->add_ldif('t/test-data/ldap/people.ldif'), 'added LDAP data; people';

    # VERIFY: explicit lookup by username finds the Default User
    $user = Socialtext::User->new(username => $email_address);
    isa_ok $user, 'Socialtext::User', 'User found by explicit username lookup';
    is $user->homunculus->driver_name, 'Default', '... is the old Default user';

    # VERIFY: explicit lookup by e-mail address finds the LDAP User
    $user = Socialtext::User->new(email_address => $email_address);
    isa_ok $user, 'Socialtext::User', 'User found by explicit e-mail lookup';
    is $user->homunculus->driver_name, 'LDAP', '... is the LDAP user';

    # TEST: Resolving the user by e-mail address should give us the LDAP user
    $user = Socialtext::User->Resolve($email_address);
    isa_ok $user, 'Socialtext::User', 'Resolved User';
    is $user->homunculus->driver_name, 'LDAP', '... is the LDAP user';
}
