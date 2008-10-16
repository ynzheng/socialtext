# @COPYRIGHT@
package Socialtext::User::Default::Factory;
use strict;
use warnings;

# allow for the system level account usernames to be exported; ST::User will
# use them to short-circuit user lookups into here where applicable.
use base qw(Exporter);
our @EXPORT_OK;
BEGIN {
    @EXPORT_OK = qw(
        $SystemUsername
        $GuestUsername
    );
}

use Socialtext::Exceptions qw( data_validation_error );

use Digest::SHA1 ();
use Email::Valid;
use Socialtext::User::Cache;
use Socialtext::Data;
use Socialtext::String;
use Socialtext::SQL qw(sql_execute sql_singlevalue);
use Socialtext::User;
use Socialtext::UserMetadata;
use Socialtext::User::Default;
use Socialtext::MultiCursor;
use Socialtext::l10n qw(loc);

our $SystemUsername = 'system-user';
our $SystemEmailAddress = 'system-user@socialtext.net';

our $GuestUsername  = 'guest';
our $GuestEmailAddress = 'guest@socialtext.net';

sub driver_name { 'Default' }
sub driver_key { shift->driver_name }

# FIXME: This belongs elsewhere, in fixture generation code, perhaps
sub _create_default_user {
    my $self = shift;
    my ($username, $email, $first_name, $created_by) = @_;

    my $id = Socialtext::User::Base->NewUserId();
    my $system_user = $self->create(
        driver_unique_id => $id,
        user_id          => $id,
        username         => $username,
        email_address    => $email,
        first_name       => $first_name,
        last_name        => 'User',
        password         => '*no-password*',
        no_crypt         => 1,
    );
    Socialtext::UserMetadata->create(
        user_id            => $id,
        created_by_user_id => $created_by,
        is_system_created  => 1,
        primary_account_id => Socialtext::Account->Socialtext->account_id(),
    );

    return $id;
}

sub EnsureRequiredDataIsPresent {
    my $class = shift;

    # create a default instance of the User factory
    my $factory = $class->new();

    # set up the required data
    unless ($factory->GetUser(username => $SystemUsername)) {
        $factory->_create_default_user(
            $SystemUsername, $SystemEmailAddress,
            'System', undef
        );
    }

    unless ($factory->GetUser(username => $GuestUsername)) {
        my $system_user = Socialtext::User->new(username => $SystemUsername);
        $factory->_create_default_user(
            $GuestUsername, $GuestEmailAddress,
            'Guest', $system_user->user_id
        );
    }
}

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = { };
    bless $self, $class;
}

{
    # optimized for hash-lookup; it'll be done on every user instantiation, so
    # make it fast.
    my %RequiredDefaultUsers = (
        username => {
            $SystemUsername => 1,
            $GuestUsername  => 1,
        },
        email_address => {
            $SystemEmailAddress => 1,
            $GuestEmailAddress  => 1,
        },
    );

    sub IsDefaultUser {
        my ( $class, $key, $val ) = @_;
        return $RequiredDefaultUsers{$key}{lc($val)};
    }
}

sub Count {
    my $self = shift;
    return sql_singlevalue(
        'SELECT COUNT(*) FROM users WHERE driver_key=?',
        $self->driver_key
    );
}

sub GetUser {
    my ( $self, $id_key, $id_val ) = @_;

    my $homunculus = Socialtext::User::Default->GetUserRecord(
        $id_key, $id_val, $self->driver_key
    );
    return $homunculus;
}

sub create {
    my ( $self, %p ) = @_;

    $self->_validate_and_clean_data(undef, \%p);

    $p{first_name}       ||= '';
    $p{last_name}        ||= '';

    $p{driver_key}       = $self->driver_key;
    $p{driver_unique_id} = $p{user_id};

    $p{driver_username} = delete $p{username};
    Socialtext::User::Base->NewUserRecord(\%p);
    $p{username} = delete $p{driver_username};

    return Socialtext::User::Default->new_from_hash(\%p);
}

# "update" methods: generic update?
sub update {
    my ( $self, $user, %p ) = @_;

    $self->_validate_and_clean_data($user, \%p);

    $p{cached_at} = DateTime::Infinite::Future->new();
    delete $p{driver_key}; # can't update, sorry

    Socialtext::User::Base->UpdateUserRecord( {
        %p,
        driver_username => $p{username},
        user_id => $user->user_id,
    } );

    while (my ($column, $value) = each %p) {
        $user->$column($value);
    }

    # flush cache; updated User in DB
    Socialtext::User::Cache->Clear();

    return $user;
}


# Required Socialtext::User plugin methods

sub Search {
    my $self = shift;
    my $search_term = shift;

    # SANITY CHECK: have inbound parameters
    return unless $search_term;

    # build/execute the search
    my $splat_term = lc "\%$search_term\%";

    my $sth = sql_execute(q{
            SELECT first_name, last_name, email_address
              FROM users 
             WHERE ( 
                     LOWER( driver_username ) LIKE ? OR
                     LOWER( email_address ) LIKE ? OR
                     LOWER( first_name ) LIKE ? OR
                     LOWER( last_name ) LIKE ? 
                   ) 
                   AND ( driver_key = ? )
                   AND ( driver_username NOT IN (?, ?) )
        },
        $splat_term, $splat_term, $splat_term, $splat_term,
        $self->driver_key,
        $SystemUsername, $GuestUsername
    );

    return Socialtext::MultiCursor->new(
        iterables => [ $sth->fetchall_arrayref ],
        apply => sub {
            my $row = shift;
            my $name = Socialtext::User->FormattedEmail(@$row);
            return {
                driver_name    => $self->driver_key,
                email_address  => $row->[2],
                name_and_email => $name,
            };
        },
    )->all;
}

# Helper methods

sub _validate_and_clean_data {
    my $self = shift;
    my $user = shift;
    my $p = shift;
    my $metadata;

    my $is_create = defined $user ? 0 : 1;

    if ($is_create) {
        $p->{user_id} ||= Socialtext::User::Base->NewUserId();
    }
    else {
        $metadata = Socialtext::UserMetadata->new(
            user_id => $user->user_id
        );
    }

    my @errors;
    for my $k (qw(username email_address)) {
        $p->{$k} = Socialtext::String::trim( lc $p->{$k} )
            if defined $p->{$k};

        if (defined $p->{$k}
            and (  $is_create
                or $p->{$k} ne $user->$k())
            and Socialtext::User->new_homunculus($k => $p->{$k}))
        {
            push @errors, loc("The [_1] you provided ([_2]) is already in use.", Socialtext::Data::humanize_column_name($k), $p->{$k});
        }

        if ((exists $p->{$k} or $is_create)
            and not(defined $p->{$k} and length $p->{$k}))
        {
            push @errors,
                    loc('[_1] is a required field.', 
                        ucfirst Socialtext::Data::humanize_column_name($k));

        }
    }

    if (defined $p->{email_address}
        and length $p->{email_address}
        and !Email::Valid->address($p->{email_address}))
    {
        push @errors,
            loc(
            "[_1] is not a valid email address.",
            $p->{email_address}
            );
    }

    if (defined $p->{password} && length $p->{password} < 6) {
        push @errors, Socialtext::User::Default->ValidatePassword(
            password => $p->{password});
    }

    if (delete $p->{require_password}
        and $is_create
        and not defined $p->{password})
    {
        push @errors, loc('A password is required to create a new user.');
    }

    if (!$is_create and $metadata and $metadata->is_system_created) {
        push @errors,
            loc("You cannot change the name of a system-created user.")
            if $p->{username};

        push @errors,
            loc("You cannot change the email address of a system-created user.")
            if $p->{email_address};
    }

    data_validation_error errors => \@errors if @errors;

    if ($is_create
        and not(defined $p->{password} and length $p->{password}))
    {
        $p->{password} = '*none*';
        $p->{no_crypt} = 1;
    }

    # we don't care about different salt per-user - we crypt to
    # obscure passwords from ST admins, not for real protection (in
    # which case we would not use crypt)
    $p->{password} = Socialtext::User::Default->_crypt( $p->{password}, 'salty' )
        if exists $p->{password} && ! delete $p->{no_crypt};

    if ( $is_create and $p->{username} ne $SystemUsername ) {
        # this will not exist when we are making the system user!
        $p->{created_by_user_id} ||= Socialtext::User->SystemUser()->user_id;
    }
}

1;

__END__

=head1 NAME

Socialtext::User::Default::Factory - A Socialtext RDBMS User Factory

=head1 SYNOPSIS

  use Socialtext::User::Default::Factory;

  # instantiate default RDBMS factory
  $factory = Socialtext::User::Default::Factory->new();

  # instantiate user
  $user = $factory->GetUser( user_id => $user_id );
  $user = $factory->GetUser( username => $username );
  $user = $factory->GetUser( email_address => $email_address );

    # user search
  @results = $factory->Search( 'foo' );

=head1 DESCRIPTION

C<Socialtext::User::Default::Factory> provides a a User factory for users that
live in our User table.  Each object represents a single row from the table.

=head1 METHODS

=over

=item B<Socialtext::User::Default::Factory-E<gt>new()>

Creates a new RDBMS user factory.

=item B<driver_name()>

Returns the name of the driver this Factory implements, "Default".

=item B<driver_key()>

Returns the unique ID of the driver instance used by this Factory.  The
Default driver only has B<one> instance, so this is the same as the
L</driver_name()>.

=item B<Socialtext::User::Default::Factory->E<gt>EnsureRequiredDataIsPresent()>

Inserts required users into the DBMS if they are not present.  See
L<Socialtext::Data> fo rmore details on required data.

=item B<Socialtext::User::Default::Factory-E<gt>IsDefaultUser($key, $val)>

Checks to see if the user defined by the given C<%args> is one of the users
that B<must> reside in the Default data store (the system-level user records).
This method returns true if the user must reside in the Default store,
returning false otherwise.

Lookups can be performed by I<one> of:

=over

=item * username => $username

=item * email_address => $email_address

=back

=item B<Socialtext::User::Default::Factory->E<gt>Count()>

Returns the number of User records in the database.

=item B<GetUser($key, $val)>

Searches for the specified user in the RDBMS data store and returns a new
C<Socialtext::User::Default> object representing that user if it exists.

User lookups can be performed by I<one> of:

=over

=item * user_id => $user_id

=item * username => $username

=item * email_address => $email_address

=back

=item B<create(%params)>

Attempts to create a user with the given information and returns a new
C<Socialtext::User::Default> object representing the new user.

Valid C<%params> include:

=over

=item * username - required

=item * email_address - required

=item * password - see below for default

Normally, the value for "password" should be provided in unencrypted
form.  It will be stored in the DBMS in C<crypt()>ed form.  If you
must pass in a crypted password, you can also pass C<< no_crypt => 1
>> to the method.

The password must be at least six characters long.

If no password is specified, the password will be stored as the string
"*none*", unencrypted. This will cause the C<<
$user->has_valid_password() >> method to return false for this user.

=item * require_password - defaults to false

If this is true, then the absence of a "password" parameter is
considered an error.

=item * first_name

=item * last_name

=back

=item B<update($user, %params)>

Updates the user's information with the new key/val pairs passed in.  You
cannot change username or email_address for a row where is_system_created is
true.

=item B<Socialtext::User::Default::Factory-E<gt>Search($term)>

Search for user records where the given search C<$term> is found in any one
of the following fields:

=over

=item * username

=item * email_address

=item * first_name

=item * last_name

=back

The search will return back to the caller a list of hash-refs containing the
following key/value pairs:

=over

=item driver_name

The unique driver key for the instance of the data store that the user was
found in.  e.g. "Default".

=item email_address

The e-mail address for the user.

=item name_and_email

The canonical name and e-mail for this user, as produced by
C<Socialtext::User-E<gt>FormattedEmail()>.

=back

=back

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005 Socialtext, Inc., All Rights Reserved.

=cut
