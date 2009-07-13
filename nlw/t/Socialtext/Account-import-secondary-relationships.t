#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use File::Path qw(rmtree);
use Test::Socialtext tests => 7;
use Test::Socialtext::User;
use Test::Socialtext::Account;

use Socialtext::CLI;
use t::Socialtext::CLITestUtils qw(expect_success);

###############################################################################
###############################################################################
### Verify that when a User only has a _secondary_ relationship to an Account,
### that they *are* exported along with that Account, and that on re-import
### into a fresh/clean Appliance, they are placed in the "Default" Account (as
### their old Primary Account doesn't exist on this new Appliance).
###
### e.g. we exported an Account on "prod" and then re-imported it back onto a
### new appliance
###############################################################################
###############################################################################

###############################################################################
# Fixtures: db
# - need a DB, but don't care what's in it.
fixtures(qw( db ));

###############################################################################
# Over-ride the root directory for Account exports
$ENV{ST_EXPORT_DIR} = 't/tmp';

###############################################################################
# Set up some test Users, across multiple accounts.  One of these Users
# ($user_three) is going to live in *two* different accounts; he's the one
# that we're really concerned about.
my $default_acct   = Socialtext::Account->Default;

my $test_account   = create_test_account_bypassing_factory();
my $test_acct_id   = $test_account->account_id();
my $test_acct_name = $test_account->name();
my $user_one       = create_test_user(account => $test_account);
my $user_two       = create_test_user(account => $test_account);

my $dummy_account  = create_test_account_bypassing_factory();
my $test_user      = create_test_user(account => $dummy_account);
my $test_user_name = $test_user->username();

my $test_ws        = create_test_workspace(
    account => $test_account,
    user    => $test_user,
);

###############################################################################
# Build up the path to where we expect the Account to get exported to
my $exported_path = File::Spec->catfile(
    $ENV{ST_EXPORT_DIR},
    "${test_acct_name}.id-${test_acct_id}.export",
);

###############################################################################
# Export the Account, using the *CLI* (calling "export()" on the Account
# object just exports the Account, but none of the Workspaces that it
# contains).
expect_success(
    sub {
        Socialtext::CLI->new(
            argv => ['--account', $test_acct_name],
        )->export_account(),
    },
    qr/account exported to/,
    'Account exported successfully'
);

###############################################################################
# Clean *everything* out, so we can re-import the Users+Account all over again
Test::Socialtext::User->delete_recklessly( $user_one );
Test::Socialtext::User->delete_recklessly( $user_two );
Test::Socialtext::User->delete_recklessly( $test_user );
$test_ws->delete();
Test::Socialtext::Account->delete_recklessly( $test_account );
Test::Socialtext::Account->delete_recklessly( $dummy_account );

###############################################################################
# Re-import the Account.
expect_success(
    sub {
        Socialtext::CLI->new(
            argv => ['--dir', $exported_path],
        )->import_account();
    },
    qr/account imported/,
    'Account re-imported successfully'
);

my $reimported_acct = Socialtext::Account->new(name => $test_acct_name);
isa_ok $reimported_acct, 'Socialtext::Account', '... Account re-imported';

###############################################################################
# Re-instantiate the Test User that we're concerned about.  He *should* have
# been placed in the "Default" Account (as his primary account doesn't exist
# here).  Actually, it's more like "he's *not* in the Account we just
# imported", but this _should_ mean that he goes to the Default Account.
my $reimported_user = Socialtext::User->new(username => $test_user_name);
isa_ok $reimported_user, 'Socialtext::User', '... Test User re-imported';

is $reimported_user->primary_account->name, $default_acct->name,
    '... and he was placed in the Default account';

###############################################################################
# Cleanup
rmtree $exported_path;
