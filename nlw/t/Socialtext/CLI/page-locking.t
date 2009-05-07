#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext qw/no_plan/;
use Socialtext::CLI;
use t::Socialtext::CLITestUtils qw/expect_success expect_failure/;

fixtures( 'admin', 'destructive' );

lock_page: {
    # Workspace cannot lock pages.
    expect_failure(
        sub {
            Socialtext::CLI->new( 
                argv => [ qw/--workspace admin --page admin_wiki/ ]
            )->lock_page();
        },
        qr/\QPage locking is turned off for workspace 'Admin Wiki'.\E/,
        'page lock fails when workspace does not allow page locking'
    );

    expect_success(
        sub {
            # make pages lockable.
            Socialtext::CLI->new(
                argv => [qw/--workspace admin allows_page_locking 1/]
            )->set_workspace_config();
        },
        qr/\QThe workspace config for admin has been updated.\E/,
        'page locking turned on'
    );

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [ qw/--workspace admin --page admin_wiki/ ]
            )->lock_page();
        },
        qr/\QPage 'Admin Wiki' in workspace 'Admin Wiki' has been locked.\E/,
        'page lock success'
    );

    # Page does not exist
    expect_failure(
        sub {
            Socialtext::CLI->new( 
                argv => [ qw/--workspace admin --page ENOSUCH/ ]
            )->lock_page();
        },
        qr/\QThere is no page with the id "ENOSUCH" in the admin workspace.\E/,
        'page lock fails when page does not exist'
    );

    # Workspace does not exist
    expect_failure(
        sub {
            Socialtext::CLI->new( 
                argv => [ qw/--workspace ENOSUCH --page admin_wiki/ ]
            )->lock_page();
        },
        qr/\QNo workspace named "ENOSUCH" could be found.\E/,
        'page lock fails when workspace does not exist'
    );
}

# We don't need to re-run the whole battery of tests above because these
# calls share code.
unlock_page: {
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [ qw/--workspace admin --page admin_wiki/ ]
            )->unlock_page();
        },
        qr/\QPage 'Admin Wiki' in workspace 'Admin Wiki' has been unlocked.\E/,
        'page unlock success'
    );
}

can_lock_pages: {
    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [ qw/--workspace admin --email devnull1@socialtext.com/ ]
            )->can_lock_pages();
        },
        qr/User\ \'devnull1\@socialtext\.com\'\ can\ lock\ a\ page\./,
        'user can lock pages'
    );

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [ qw/--workspace admin --email q@q.q/ ]
            )->remove_workspace_admin();
        },
        qr/./,
        'remove admin privs for q@q.q'
    );

    expect_success(
        sub {
            Socialtext::CLI->new(
                argv => [ qw/--workspace admin --email q@q.q/ ]
            )->can_lock_pages();
        },
        qr/User\ \'q\@q\.q\'\ cannot\ lock\ a\ page\./,
        'user cannot lock pages'
    );
}
