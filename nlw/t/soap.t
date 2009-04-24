#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext;
fixtures( 'admin' );

my @tests = (
    [ "{soap bogus_service bogus method}" =>
      qr{Service description 'bogus_service' can't be loaded: 400}],
    [ "{soap http://staff.um.edu.mt/cabe2/supervising/undergraduate/owlseditFYP/TemperatureService.wsdl getTemp 47408}" =>
      qr{47408}],
    [ "{googlesoap chris dent}" =>
      qr{<b>Chris Dent</b>}],
);

plan tests => scalar @tests;

my $hub = new_hub('admin');
my $viewer = $hub->viewer;

SKIP: {
    skip "soap access the network, skipping", scalar @tests
        unless ($ENV{NLW_TEST_SOAP} || $ENV{NLW_TEST_NETWORK});
    for my $test (@tests)
    {
        # XXX \n needed to insure wafl is seen
        my $result = $viewer->text_to_html( $test->[0] . "\n");
        like( $result, $test->[1], $test->[0] );
    }
}
