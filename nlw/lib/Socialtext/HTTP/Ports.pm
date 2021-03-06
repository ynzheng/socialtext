package Socialtext::HTTP::Ports;
# @COPYRIGHT@

use strict;
use warnings;
use Socialtext::AppConfig;
use Class::Field qw(const);

###############################################################################
# Export our constants, so they can be used in our test suite
use base qw(Exporter);
our @EXPORT_OK = qw(
    STANDARD_HTTP_PORT
    STANDARD_HTTPS_PORT
    STANDARD_BACKEND_PORT
    PORTS_START_AT
    SSL_PORT_DIFFERENCE
    BACKEND_PORT_DIFFERENCE
);
our %EXPORT_TAGS = (
    constants => [qw(
        STANDARD_HTTP_PORT
        STANDARD_HTTPS_PORT
        STANDARD_BACKEND_PORT
        PORTS_START_AT
        SSL_PORT_DIFFERENCE
        BACKEND_PORT_DIFFERENCE
    )],
);

###############################################################################
# constant values
const STANDARD_HTTP_PORT      => 80;
const STANDARD_HTTPS_PORT     => 443;
const STANDARD_BACKEND_PORT   => 8080;
const PORTS_START_AT          => 20000;
const SSL_PORT_DIFFERENCE     => 1000;
const BACKEND_PORT_DIFFERENCE => 2000;

###############################################################################
sub http_port {
    return _env_var_http_port()                 # ENV var over-ride
        || _configured_http_port()              # ST::AppConfig
        || _default_http_port();                # default
}

sub https_port {
    return _configured_https_port()             # ST::AppConfig
        || _default_https_port();               # default
}

sub backend_http_port {
    return _default_backend_http_port();        # default
}

sub backend_https_port {
    return _default_backend_https_port();       # default
}

###############################################################################
# Helpers: front-end HTTP port
sub _env_var_http_port {
    return $ENV{NLW_FRONTEND_PORT};
}
sub _configured_http_port {
    return Socialtext::AppConfig->custom_http_port();
}
sub _default_http_port {
    return Socialtext::AppConfig->is_appliance()
        ? _default_appliance_http_port()
        : _default_devenv_http_port()
}
sub _default_appliance_http_port {
    return STANDARD_HTTP_PORT();
}
sub _default_devenv_http_port {
    return PORTS_START_AT() + $>;
}

###############################################################################
# Helpers: front-end HTTPS port
sub _configured_https_port {
    return Socialtext::AppConfig->ssl_port();
}
sub _default_https_port {
    return Socialtext::AppConfig->is_appliance()
        ? _default_appliance_https_port()
        : _default_devenv_https_port()
}
sub _default_appliance_https_port {
    return STANDARD_HTTPS_PORT();
}
sub _default_devenv_https_port {
    return _default_devenv_http_port() + SSL_PORT_DIFFERENCE();
}

###############################################################################
# Helpers: back-end HTTP port
sub _default_backend_http_port {
    return Socialtext::AppConfig->is_appliance()
        ? _default_appliance_backend_http_port()
        : _default_devenv_backend_http_port()
}
sub _default_appliance_backend_http_port {
    return STANDARD_BACKEND_PORT();
}
sub _default_devenv_backend_http_port {
    return _default_devenv_http_port() + BACKEND_PORT_DIFFERENCE();
}

###############################################################################
# Helpers: back-end HTTPS port
sub _default_backend_https_port {
    return Socialtext::AppConfig->is_appliance()
        ? _default_appliance_backend_https_port()
        : _default_devenv_backend_https_port();
}
sub _default_appliance_backend_https_port {
    return _default_appliance_backend_http_port() + SSL_PORT_DIFFERENCE();
}
sub _default_devenv_backend_https_port {
    return _default_devenv_backend_http_port() + SSL_PORT_DIFFERENCE();
}

1;

=head1 NAME

Socialtext::HTTP::Ports - Determine which ports are used for HTTP/HTTPS

=head1 SYNOPSIS

  use Socialtext::HTTP::Ports;

  # determine the HTTP(s) ports used for the Apache2 front-end
  $frontend_http_port  = Socialtext::HTTP::Ports->http_port();
  $frontend_https_port = Socialtext::HTTP::Ports->https_port();

  # determine the HTTP ports used for the Apache/ModPerl back-end
  $backend_http_port  = Socialtext::HTTP::Ports->backend_http_port();
  $backend_https_port = Socialtext::HTTP::Ports->backend_https_port();

=head1 DESCRIPTION

C<Socialtext::HTTP::Ports> provides a series of methods to help determine what
the HTTP/HTTPS ports are used by the Apache2 front-end and the Apache/ModPerl
back-end.

These methods are safe to call both in order to determine "what are the
default HTTP(s) ports to use" as well as "what HTTP(s) ports I<have been
configured> for use".

=head1 METHODS

=over

=item B<Socialtext::HTTP::Ports-E<gt>http_port()>

Returns the port number that is used for HTTP connections in the Apache2
front-end.

=item B<Socialtext::HTTP::Ports-E<gt>https_port()>

Returns the port number that is used for HTTPS connections in the Apache2
front-end.

=item B<Socialtext::HTTP::Ports-E<gt>backend_http_port()>

Returns the port number that is used for HTTP connections in the
Apache/ModPerl back-end.

=item B<Socialtext::HTTP::Ports-E<gt>backend_https_port()>

Returns the port number that is used for HTTPS connections in the
Apache/ModPerl back-end.

=back

=head1 AUTHOR

Socialtext, Inc., C<< <code@socialtext.com> >>

=head1 COPYRIGHT

Copyright 2009 Socialtext, Inc., All Rights Reserved.

=cut
