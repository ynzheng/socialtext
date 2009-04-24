#!perl
# @COPYRIGHT@
use warnings;
use strict;
use Test::Socialtext tests => 41;
use Socialtext::Account;
use File::Slurp qw(write_file);
use Socialtext::SQL qw/:exec/;

BEGIN { use_ok 'Socialtext::CLI' }
use t::Socialtext::CLITestUtils qw/expect_failure expect_success/;

#fixtures( 'workspaces_with_extra_pages', 'destructive' );
fixtures( 'workspaces_with_extra_pages' );

my $new_default = Socialtext::Account->create(
    name => "MassAdd$^T",
);
ok $new_default;
eval { $new_default->enable_plugin('people') };

my $specific_acct = Socialtext::Account->create(
    name => "Specific$^T",
);
ok $specific_acct;
eval { $specific_acct->enable_plugin('people') };

{
    my $old_default = sql_singlevalue(
        q{SELECT value FROM "System" WHERE field = 'default-account'});
    # Get rid of any existing default account
    sql_execute(q{DELETE FROM "System" WHERE field = 'default-account'});
    sql_execute(
        q{INSERT INTO "System" (field,value) VALUES ('default-account',?)},
        $new_default->account_id
    );

    END {
        # restore after the test
        sql_execute(q{DELETE FROM "System" WHERE field = 'default-account'});
        sql_execute(
            q{INSERT INTO "System" (field,value) VALUES ('default-account',?)},
            $old_default
        ) if $old_default;
    }
}

MASS_ADD_USERS: {
    # success; add some users from CSV
    #   - run CLI tool, success
    #   - find users in DB, verify contents
    add_users_from_csv: {
        # create CSV file
        my $csvfile = Cwd::abs_path(
            (File::Temp::tempfile(SUFFIX=>'.csv', OPEN=>0))[1]
        );
        write_file $csvfile,
            join(',', qw{username email_address first_name last_name password position company location work_phone mobile_phone home_phone}) . "\n",
            join(',', qw{csvtest1 csvtest1@example.com John Doe passw0rd position company location work_phone mobile_phone home_phone}) . "\n",
            join(',', qw{csvtest2 csvtest2@example.com Jane Smith password2 position2 company2 location2 work_phone2 mobile_phone2 home_phone2}) . "\n";

        # do mass-add
        expect_success(
            sub {
                Socialtext::CLI->new(
                    argv => ['--csv', $csvfile]
                )->mass_add_users();
            },
            qr/\QAdded user csvtest1\E.*\QAdded user csvtest2\E/s,
            'mass-add-users successfully added users',
        );
        unlink $csvfile;

        # verify first user was added, including all fields
        my $user = Socialtext::User->new( username => 'csvtest1' );
        ok $user, 'csvtest1 user was created via mass_add_users';
        is $user->email_address, 'csvtest1@example.com', '... email_address was set';
        is $user->first_name, 'John', '... first_name was set';
        is $user->last_name, 'Doe', '... last_name was set';
        ok $user->password_is_correct('passw0rd'), '... password was set';
        is $user->primary_account->account_id, $new_default->account_id,
            'user has default primary_account';

        SKIP: {
            skip 'Socialtext People is not installed', 7 unless $Socialtext::MassAdd::Has_People_Installed;
            my $profile = Socialtext::People::Profile->GetProfile($user, no_recurse => 1);
            ok $profile, '... ST People profile was created';
            is $profile->get_attr('position'), 'position', '... ... position was set';
            is $profile->get_attr('company'), 'company', '... ... company was set';
            is $profile->get_attr('location'), 'location', '... ... location was set';
            is $profile->get_attr('work_phone'), 'work_phone', '... ... work_phone was set';
            is $profile->get_attr('mobile_phone'), 'mobile_phone', '... ... mobile_phone was set';
            is $profile->get_attr('home_phone'), 'home_phone', '... ... home_phone was set';
        }

        # verify second user was added, but presume fields were added ok
        $user = Socialtext::User->new( username => 'csvtest2' );
        ok $user, 'csvtest2 user was created via mass_add_users';
    }

    add_users_from_csv_with_account: {
        # create CSV file
        my $csvfile = Cwd::abs_path(
            (File::Temp::tempfile(SUFFIX=>'.csv', OPEN=>0))[1]
        );
        write_file $csvfile,
            join(',', qw{username email_address first_name last_name password position company location work_phone mobile_phone home_phone}) . "\n",
            join(',', qw{csvtest3 csvtest3@example.com John Doe passw0rd position company location work_phone mobile_phone home_phone}) . "\n";

        # do mass-add
        expect_success(
            sub {
                Socialtext::CLI->new(
                    argv => ['--csv', $csvfile, '--account', "Specific$^T"]
                )->mass_add_users();
            },
            qr/\QAdded user csvtest3\E/,
            'mass-add-users successfully added users',
        );
        unlink $csvfile;

        # verify first user was added, including all fields
        my $user = Socialtext::User->new( username => 'csvtest3' );
        ok $user, 'csvtest1 user was created via mass_add_users';
        is $user->primary_account->account_id, $specific_acct->account_id,
            'user has specific primary_account';
    }

    # success; update users from CSV
    #   - run CLI tool, success
    #   - find users in DB, verify update
    update_users_from_csv: {
        # create CSV file, using user from above test
        my $csvfile = Cwd::abs_path(
            (File::Temp::tempfile(SUFFIX=>'.csv', OPEN=>0))[1]
        );
        write_file $csvfile,
            join(',', qw{username email_address first_name last_name password position}) . "\n",
            join(',', qw(csvtest1 email@example.com u_John u_Doe u_passw0rd u_position));

        # make sure that the user really does exist
        my $user = Socialtext::User->new( username => 'csvtest1' );
        ok $user, 'csvtest1 user exists prior to update';

        # do mass-update
        expect_success(
            sub {
                Socialtext::CLI->new(
                    argv => ['--csv', $csvfile, '--account', "Specific$^T"],
                )->mass_add_users();
            },
            qr/\QUpdated user csvtest1\E/,
            'mass-add-users successfully updated users',
        );
        unlink $csvfile;

        # verify user was updated, including the People fields
        $user = Socialtext::User->new( username => 'csvtest1' );
        ok $user, 'csvtest1 user still around after update';
        is $user->email_address, 'csvtest1@example.com', '... email was *NOT* updated (by design)';
        is $user->first_name, 'u_John', '... first_name was updated';
        is $user->last_name, 'u_Doe', '... last_name was updated';
        ok $user->password_is_correct('u_passw0rd'), '... password was updated';
        is $user->primary_account->account_id, $specific_acct->account_id,
            'mass updated user changed account';

        SKIP: {
            skip 'Socialtext People is not installed', 2 unless $Socialtext::MassAdd::Has_People_Installed;
            my $profile = Socialtext::People::Profile->GetProfile($user, no_recurse => 1);
            ok $profile, '... ST People profile was found';
            is $profile->get_attr('position'), 'u_position', '... ... position was updated';
        }
    }

    # failure; email in use by another user
    email_in_use_by_another_user: {
        # create CSV file, using e-mail from a known existing user
        my $csvfile = Cwd::abs_path(
            (File::Temp::tempfile(SUFFIX=>'.csv', OPEN=>0))[1]
        );
        write_file $csvfile,
            join(',', qw{username email_address first_name last_name password}) . "\n",
            join(',', qw(csv_email_clash devnull1@socialtext.com John Doe passw0rd));

        # make sure that the user really does exist
        my $user = Socialtext::User->new( email_address => 'devnull1@socialtext.com' );
        ok $user, 'user does exist with clashing e-mail address';

        # do mass-add
        expect_failure(
            sub {
                Socialtext::CLI->new(
                    argv => ['--csv', $csvfile],
                )->mass_add_users();
            },
            qr/Line 2: The email address you provided \(devnull1\@socialtext.com\) is already in use./,
            'mass-add-users does not add user if email in use'
        );
        unlink $csvfile;
    }

    # failure; no CSV file provided
    no_csv_file_provided: {
        expect_failure(
            sub { 
                Socialtext::CLI->new( argv=>[] )->mass_add_users();
            },
            qr/\QThe file you provided could not be read\E/,
            'mass-add-users failed with no args'
        );
    }

    # failure; file is not CSV
    file_is_not_csv: {
        # create bogus file
        my $csvfile = Cwd::abs_path(
            (File::Temp::tempfile(SUFFIX=>'.csv', OPEN=>0))[1]
        );
        write_file $csvfile,
            join(',', qw{username email_address first_name last_name password}) . "\n",
            join(' ', qw{csvtest1 csvtest1@example.com John Doe passw0rd}) . "\n";

        # do mass-add
        expect_failure(
            sub {
                Socialtext::CLI->new(
                    argv => ['--csv', $csvfile]
                )->mass_add_users();
            },
            qr/\QLine 2: could not be parsed (missing fields).  Skipping this user.\E/,
            'mass-add-users failed with invalid file'
        );
        unlink $csvfile;
    }
}
