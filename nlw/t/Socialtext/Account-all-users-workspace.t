#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 21;
use Test::Exception;
use Test::Warn;

use Socialtext::User;

use_ok 'Socialtext::Account';

################################################################################
# TEST: Set all_users_workspace
set_all_users_workspace: {
    my $acct = create_test_account();
    my $ws   = create_test_workspace(account => $acct);

    # update the all_users_workspace
    $acct->update( all_users_workspace => $ws->workspace_id );

    is $acct->all_users_workspace, $ws->workspace_id, 
        'Set all users workspace.';
}

################################################################################
# TEST: Set all_users_workspace, workspace does not exist
set_workspace_does_not_exist: {
    my $acct = create_test_account();

    dies_ok {
        $acct->update( all_users_workspace => '-2000' );
    } 'dies when workspace does not exist';

    is $acct->all_users_workspace, undef, '... all users workspace not updated';
}

################################################################################
# TEST: Set all_users_workspace, workspace not in account
set_workspace_not_in_account: {
    my $acct = create_test_account();
    my $ws   = create_test_workspace();

    dies_ok {
        $acct->update( all_users_workspace => $ws->workspace_id );
    } 'dies when workspace is not in account';

    is $acct->all_users_workspace, undef, '... all users workspace not updated';
}

################################################################################
# TEST: Add user to account no all users workspace.
account_no_workspace: {
    my $acct = create_test_account();
    my $ws   = create_test_workspace(account => $acct);
    my $user = create_test_user(account => $acct);

    my $ws_users = $ws->users;
    isa_ok $ws_users, 'Socialtext::MultiCursor';
    is $ws_users->count, 0, '... with no users';
}

################################################################################
# TEST: add user to all users workspace, not in account
user_not_in_account: {
    my $other_acct = create_test_account();
    my $acct       = create_test_account();
    my $ws         = create_test_workspace(account => $acct);
    my $user       = create_test_user();

    # Make the workspace the all account workspace.
    $acct->update( all_users_workspace => $ws->workspace_id );

    # fails silently
    $acct->add_to_all_users_workspace( user_id => $user->user_id );

    my $ws_users = $ws->users;
    isa_ok $ws_users, 'Socialtext::MultiCursor';
    is $ws_users->count, 0, '... with no users';
}

################################################################################
# TEST: Add/Remove user to account with all users workspace ( high level ).
account_with_workspace_high_level: {
    my $other_acct = create_test_account();
    my $acct       = create_test_account();
    my $ws         = create_test_workspace(account => $acct);

    # Make the workspace the all account workspace.
    $acct->update( all_users_workspace => $ws->workspace_id );

    # Make sure the user is in the account.
    my $user = create_test_user();
    $user->primary_account( $acct );

    my $ws_users = $ws->users;
    isa_ok $ws_users, 'Socialtext::MultiCursor';
    is $ws_users->count, 1, '... with one user';
    
    my $ws_user = $ws_users->next();
    is $ws_user->username, $user->username, '... who is the correct user';

    # Change user's primary account
    $user->primary_account( $other_acct );

    $ws_users = $ws->users;
    isa_ok $ws_users, 'Socialtext::MultiCursor';
    is $ws_users->count, 0, '... with no users';
}

################################################################################
# TEST: user is added when all users workspace changes
account_with_workspace_high_level: {
    my $acct = create_test_account();
    my $ws   = create_test_workspace(account => $acct);
    my $user = create_test_user(account => $acct);

    # Make the workspace the all account workspace.
    $acct->update( all_users_workspace => $ws->workspace_id );

    my $ws_users = $ws->users;
    isa_ok $ws_users, 'Socialtext::MultiCursor';
    is $ws_users->count, 1, '... with one user';
}

################################################################################
# TEST: all users workspace changes, user stays in ws.
user_remains: {
    my $acct     = create_test_account();
    my $ws       = create_test_workspace(account => $acct);
    my $other_ws = create_test_workspace(account => $acct);

    # Make the workspace the all account workspace.
    $acct->update( all_users_workspace => $ws->workspace_id );

    # Make sure the user is in the account.
    my $user = create_test_user();
    $user->primary_account( $acct );

    my $ws_users = $ws->users;
    isa_ok $ws_users, 'Socialtext::MultiCursor';
    is $ws_users->count, 1, '... with one user';

    # Change account's all users workspace.
    $acct->update( all_users_workspace => $other_ws->workspace_id );

    $ws_users = $ws->users;
    isa_ok $ws_users, 'Socialtext::MultiCursor';
    is $ws_users->count, 1, '... still with one user';
}
