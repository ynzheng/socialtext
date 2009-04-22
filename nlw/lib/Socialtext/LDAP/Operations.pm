package Socialtext::LDAP::Operations;
# @COPYRIGHT@

use strict;
use warnings;
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
            st_log->error(@_);
        }
    }
    $sth->finish();

    # All done.
    st_log->info( "done" );
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

=item B<Socialtext::LDAP::Operations-E<gt>RefreshUsers()>

Refreshes known/existing LDAP Users from the configured LDAP servers.

=back

=head1 AUTHOR

Graham TerMarsch C<< <graham.termarsch@socialtext.com> >>

=head1 COPYRIGHT

Copyright 2009 Socialtext, Inc., All Rights Reserved.

=head1 SEE ALSO

L<st-refresh-ldap-users>.

=cut
