#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use mocked 'Socialtext::Log', qw(:tests);
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 31;
use Socialtext::LDAP::Operations;

###############################################################################
# FIXTURE:  db
#
# Need to have the DB around, but don't care what's in it.
fixtures(qw( db ));

###############################################################################
# ERASE any existing LDAP config, so it doesn't pollute this test suite
unlink Socialtext::LDAP::Config->config_filename();

###############################################################################
# Sets up OpenLDAP, adds some test data, and adds the OpenLDAP server to our
# list of user factories.
sub set_up_openldap {
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    $openldap->add_ldif('t/test-data/ldap/base_dn.ldif');
    $openldap->add_ldif('t/test-data/ldap/people.ldif');
    return $openldap;
}
our $NUM_TEST_USERS = 6;    # number of users in 'people.ldif'

###############################################################################
# TEST: Load successfully
test_load_successfully: {
    my $ldap = set_up_openldap();
    clear_log();

    # load Users, make sure its successful and that its logged everything
    my $rc = Socialtext::LDAP::Operations->LoadUsers();
    is $rc, $NUM_TEST_USERS, 'loaded correct number of LDAP Users';
    logged_like 'info', qr/found $NUM_TEST_USERS LDAP users to load/,
        '... logged number of LDAP Users found';

    logged_like 'info', qr/loading: john.doe/,    '... added John Doe';
    logged_like 'info', qr/loading: jane.smith/,  '... added Jane Smith';
    logged_like 'info', qr/loading: bubba.brain/, '... added Bubba Brain';
    logged_like 'info', qr/loading: jim.smith/,   '... added Jim Smith';
    logged_like 'info', qr/loading: jim.q.smith/, '... added Jim Q Smith';
    logged_like 'info', qr/loading: ray.parker/,  '... added Ray Parker';

    logged_like 'info', qr/loaded $NUM_TEST_USERS out of $NUM_TEST_USERS total/,
        '... logged success count';
}

###############################################################################
# TEST: if we've got *NO* LDAP configurations, load doesn't choke.
test_no_ldap_configurations: {
    clear_log();

    # remove any LDAP config file that might be present
    my $cfg_file = Socialtext::LDAP::Config->config_filename();
    unlink $cfg_file;
    ok !-e $cfg_file, 'no LDAP config present';

    # load Users, make sure it finds nobody to load
    my $rc = Socialtext::LDAP::Operations->LoadUsers();
    ok !$rc, 'load operation fails';
    logged_like 'info', qr/found 0 LDAP users to load/,
        '... because NO LDAP Users found to load';
}

###############################################################################
# TEST: LDAP configuration missing filter; refuses to load Users
test_ldap_config_missing_filter: {
    my $ldap = set_up_openldap();
    clear_log();

    # clear the filter in the LDAP config, and make sure it clears properly
    $ldap->ldap_config->filter(undef);
    $ldap->add_to_ldap_config();

    my $config = Socialtext::LDAP::Config->load();
    my $filter = $config->filter();
    ok !$filter, 'LDAP config contains *NO* filter';

    # load Users, make sure it fails
    my $rc = Socialtext::LDAP::Operations->LoadUsers();
    ok !$rc, 'load operation fails';
    logged_like 'error', qr/no LDAP filter in config/,
        '... load fails due to lack of LDAP filter';
}

###############################################################################
# TEST: LDAP User contains invalid/bogus data; skips that User
test_user_fails_data_validation: {
    my $ldap = set_up_openldap();
    clear_log();

    # create a test User that has an invalid e-mail address
    $ldap->add(
        'cn=Invalid Email,dc=example,dc=com',
        objectClass  => 'inetOrgPerson',
        cn           => 'Invalid Email',
        gn           => 'Invalid',
        sn           => 'Email',
        mail         => 'invalid-email',
        userPassword => 'abc123',
    );

    # load Users, make sure we tried this user, and that he failed validation
    my $rc = Socialtext::LDAP::Operations->LoadUsers();
    is $rc, $NUM_TEST_USERS, 'loaded correct number of LDAP Users';

    my $total_users = $NUM_TEST_USERS + 1;
    logged_like 'info', qr/found $total_users LDAP users to load/,
        '... logged number of LDAP Users found (including invalid user)';

    logged_like 'info', qr/loading: invalid-email/,
        '... tried adding invalid User';

    logged_like 'error', qr/invalid-email is not a valid email address/,
        '... which failed due to invalid e-mail address';
}

###############################################################################
# TEST: LDAP User missing e-mail address; isn't considered valid for loading
test_user_without_email_isnt_considered: {
    my $ldap = set_up_openldap();
    clear_log();

    # switch LDAP config around so that the "email address" attribute is going
    # to be blank for all of our test Users.
    $ldap->ldap_config->{attr_map}{email_address} = 'title';
    $ldap->add_to_ldap_config();

    my $config = Socialtext::LDAP::Config->load();
    my $attr   = $config->{attr_map}{email_address};
    is $attr, 'title', 'switched e-mail address attribute';

    # load Users, make sure the above User was *not* considered for load
    # - if the count matches the regular number of test Users, he wasn't
    #   considered for the load
    my $rc = Socialtext::LDAP::Operations->LoadUsers();
    ok !$rc, 'load operation fails';
    logged_like 'info', qr/found 0 LDAP users to load/,
        '... because NO LDAP Users found to load';
}

###############################################################################
# TEST: Dry-run; finds Users, but doesn't load any of them.
test_dry_run: {
    my $ldap = set_up_openldap();
    clear_log();

    # load Users, make sure count before+after is the same
    my $count_before = Socialtext::User->Count();

    my $rc = Socialtext::LDAP::Operations->LoadUsers(dryrun => 1);
    ok !$rc, 'did not load any LDAP Users';

    logged_like 'info', qr/found $NUM_TEST_USERS LDAP users to load/,
        '... logged number of LDAP Users found';

    logged_like 'info', qr/found: john.doe/,    '... found John Doe';
    logged_like 'info', qr/found: jane.smith/,  '... found Jane Smith';
    logged_like 'info', qr/found: bubba.brain/, '... found Bubba Brain';
    logged_like 'info', qr/found: jim.smith/,   '... found Jim Smith';
    logged_like 'info', qr/found: jim.q.smith/, '... found Jim Q Smith';
    logged_like 'info', qr/found: ray.parker/,  '... found Ray Parker';

    my $count_after = Socialtext::User->Count();
    is $count_after, $count_before,
        '... and *none* of those Users were actually added to the system';
}
