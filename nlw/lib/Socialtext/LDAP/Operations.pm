package Socialtext::LDAP::Operations;
# @COPYRIGHT@

use strict;
use warnings;
use List::MoreUtils qw(uniq);
use Socialtext::LDAP;
use Socialtext::Log qw(st_log);
use Socialtext::SQL qw(sql_execute);
use Socialtext::User::LDAP::Factory;

###############################################################################
# Refreshes existing LDAP Users.
sub RefreshUsers {
    my ($class, %opts) = @_;
    my $force = $opts{force};

    # Get the list of LDAP users *directly* from the DB.
    #
    # Order this by "driver_key" so that we'll group all of the LDAP lookups
    # for a single server together; if we spread them out we risk having the
    # LDAP connection time out in between user lookups.
    st_log->info( "getting list of LDAP users to refresh" );
    my $sth = sql_execute( qq{
        SELECT driver_key, driver_unique_id, driver_username
          FROM users
         WHERE driver_key ~* 'LDAP'
         ORDER BY driver_key, driver_username
    } );
    st_log->info( "... found " . $sth->rows . " LDAP users" );

    # Refresh each of the LDAP Users
    while (my $row = $sth->fetchrow_arrayref()) {
        my ($driver_key, $driver_unique_id, $driver_username) = @{$row};

        # get the LDAP user factory we need for this user.
        my $factory = _get_factory($driver_key);
        next unless $factory;

        # refresh the user data from the Factory, disabling cache freshness
        # checks if we're forcing the refresh of all users
        local $Socialtext::User::LDAP::Factory::CacheEnabled = 0 if ($force);
        st_log->info( "... refreshing: $driver_username" );
        my $homunculus = eval {
            $factory->GetUser( driver_unique_id => $driver_unique_id )
        };
        if ($@) {
            st_log->error($@);
        }
    }
    $sth->finish();
    _clear_factory_cache();

    # All done.
    st_log->info( "done" );
}

###############################################################################
# Loads Users from LDAP into Socialtext.
sub LoadUsers {
    my ($class, %opts) = @_;
    my $dryrun = $opts{dryrun};

    # SANITY CHECK: make sure that *ALL* of the LDAP configurations have a
    # "filter" specified.
    my @configs = Socialtext::LDAP::Config->load();
    my @missing_filter = grep { !$_->filter } @configs;
    if (@missing_filter) {
        foreach my $cfg (@missing_filter) {
            my $ldap_id = $cfg->id();
            st_log->error("no LDAP filter in config '$ldap_id'; aborting");
        }
        return;
    }

    # Query the LDAP servers to get a list of e-mail addresses for all of the
    # User records that they contain.
    my @emails;
    st_log->info( "getting list of LDAP users to load" );
    foreach my $cfg (@configs) {
        # get the LDAP attribute that contains the e-mail address
        my $mail_attr = $cfg->attr_map->{email_address};

        # query LDAP for User records that have e-mail addresses
        my $ldap = Socialtext::LDAP->new($cfg);
        my $mesg = $ldap->search(
            base    => $cfg->base(),
            scope   => 'sub',
            filter  => "($mail_attr=*)",        # HAS an e-mail address
            attrs   => [$mail_attr],            # get their e-mails
        );

        # fail/abort on *any* error (play it safe)
        unless ($mesg) {
            my $ldap_id = $cfg->id();
            st_log->error("no response from LDAP server '$ldap_id'; aborting");
            return;
        }
        if ($mesg->code) {
            my $err = $mesg->error();
            st_log->error("error while searching for Users, aborting; $err");
            return;
        }

        # gather the e-mails out of the response
        foreach my $rec ($mesg->entries()) {
            my $email = $rec->get_value($mail_attr);
            push @emails, $email;
        }
    }

    # Uniq-ify the list of e-mails.
    @emails = uniq(@emails);

    my $total_users = scalar @emails;
    st_log->info( "... found $total_users LDAP users to load" );

    # If we're doing a dry-run, log info on the Users found and STOP!
    if ($dryrun) {
        foreach my $addr (@emails) {
            st_log->info("... found: $addr");
        }
        return;
    }

    # Instantiate/vivify all of the Users.
    my $users_loaded = 0;
    foreach my $email (@emails) {
        st_log->info("... loading: $email");
        my $user = eval { Socialtext::User->new(email_address => $email) };
        if ($@) {
            st_log->error($@);
        }
        elsif (!$user) {
            st_log->error("unable to instantiate user with address '$email'");
        }
        else {
            $users_loaded++;
        }
    }
    st_log->info("Successfully loaded $users_loaded out of $total_users total LDAP Users");
    return $users_loaded;
}

###############################################################################
# Subroutine:   _get_factory($driver_key)
###############################################################################
# Gets the LDAP user Factory to use for the given '$driver_key'.  Caches the
# Factory for later re-use, so that we're not opening a new LDAP connection
# for each and every user lookup.
###############################################################################
{
    my %Factories;
    sub _get_factory {
        my $driver_key = shift;

        # create a new Factory if we don't have a cached one yet
        unless ($Factories{$driver_key}) {
            # instantiate a new LDAP user Factory
            my ($driver_id) = ($driver_key =~ /LDAP:(.*)/);
            st_log->info( "creating new LDAP user Factory, '$driver_id'" );
            my $factory = Socialtext::User::LDAP::Factory->new($driver_id);
            unless ($factory) {
                st_log->error( "unable to find LDAP config '$driver_id'; was it removed from your LDAP config?" );
                return;
            }

            # make sure we can actually connect to the LDAP server
            unless ($factory->connect()) {
                st_log->error( "unable to connect to LDAP server" );
                return;
            }

            # cache the factory for later re-use
            $Factories{$driver_key} = $factory;
        }
        return $Factories{$driver_key};
    }
    sub _clear_factory_cache {
        %Factories = ();
    }
}

1;

=head1 NAME

Socialtext::LDAP::Operations - LDAP operations

=head1 SYNOPSIS

  use Socialtext::LDAP::Operations;

  # refresh all known/existing LDAP Users
  Socialtext::LDAP::Operations->RefreshUsers();

=head1 DESCRIPTION

C<Socialtext::LDAP::Operations> implements a series of higher-level operations
that can be performed.

=head1 METHODS

=over

=item B<Socialtext::LDAP::Operations-E<gt>RefreshUsers(%opts)>

Refreshes known/existing LDAP Users from the configured LDAP servers.

Supports the following options:

=over

=item force => 1

Forces a refresh of the LDAP User data regardless of whether our local cached
copy is stale or not.  By default, only stale Users are refreshed.

=back

=item B<Socialtext::LDAP::Operations-e<gt>LoadUsers(%opts)>

Loads User records from LDAP into Socialtext from all configured LDAP
directories.

Load is performed by searching for all records in your LDAP directory that
have a valid e-mail address, and then loading each of those records into
Socialtext.

B<NOTE:> you B<must> have a C<filter> specified in your LDAP configurations
before you can load Users into Socialtext.  This is required so that it forces
you to stop and think about how you filter for "only User records" in B<your>
LDAP directories.  Without a filter, I<any> record found in LDAP that has an
e-mail address would be loaded into Socialtext, including Groups, Mailing
Lists, and any other device/item that may have an e-mail address (which most
assuredly is B<not> what you want).

Supports the following options:

=over

=item dryrun => 1

Dry-run; Users are searched for in the configured LDAP directories, but are
B<not> actually added to Socialtext.

=back

=back

=head1 AUTHOR

Graham TerMarsch C<< <graham.termarsch@socialtext.com> >>

=head1 COPYRIGHT

Copyright 2009 Socialtext, Inc., All Rights Reserved.

=head1 SEE ALSO

L<st-ldap>.

=cut
