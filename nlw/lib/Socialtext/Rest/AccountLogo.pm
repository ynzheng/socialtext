package Socialtext::Rest::AccountLogo;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Rest';
use Socialtext::Account;

#sub allowed_methods { 'GET', 'POST' }
sub allowed_methods { 'GET' }
sub workspace { return Socialtext::NoWorkspace->new() }
sub ws { '' }

sub if_authorized {
    my $self = shift;
    my $method = shift;
    my $call = shift;

    if ($method ne 'GET') {
        return $self->bad_method;
    }
#     elsif ($method eq 'POST') {
#         return $self->not_authorized
#             unless $self->_user_is_business_admin_p;
#     }

    return $self->$call(@_);
}

sub GET_image {
    my $self = shift;
    my $rest = shift;
    my $acct = Socialtext::Account->new(account_id => $self->acct);

    my $logo = $acct->logo;
    my $image_ref = eval { $logo->load(); };
    warn "Get Logo: $@" if $@;

    eval { $logo->cache_image() };
    warn "Cache Logo: $@" if $@;

    $rest->header(
        -type          => 'image/png',
        -pragma        => 'no-cache',
        -cache_control => 'no-cache, no-store',
    );
    return $$image_ref;
}

1;
