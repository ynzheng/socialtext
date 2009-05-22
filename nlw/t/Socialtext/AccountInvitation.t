#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 4;
use Email::Send::Test;
use Socialtext::Account;
use Socialtext::User;

BEGIN {
    use_ok( 'Socialtext::AccountInvitation' );
}

fixtures( 'db' );

$Socialtext::EmailSender::Base::SendClass = 'Test';

my $acct = Socialtext::Account->create( 
    name              => 'invitation',
    is_system_created => 0,
);

my $from = Socialtext::User->create(
    username           => 'invitor@example.com',
    email_address      => 'invitor@example.com',
    first_name         => 'Igor',
    last_name          => 'Vitor',
    created_by_user_id => Socialtext::User->SystemUser()->user_id,
    primary_account_id => $acct->account_id,
);

Simple_case: {
    my $invitee_email = 'invitee@example.com';
    my $invitation = Socialtext::AccountInvitation->new(
        account   => $acct,
        from_user => $from,
        invitee   => 'invitee@example.com'
    );

    eval { $invitation->send(); };
    my $e = $@;
    is $e, '', 'account invite sent';

    my $invitee = Socialtext::User->new( email_address => $invitee_email );
    ok $invitee, 'user created';
    is $invitee->primary_account_id, $acct->account_id, 'user in correct acct';
}
