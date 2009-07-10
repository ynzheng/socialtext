package Socialtext::AccountFactory;
use Moose;
use Socialtext::Account;
use namespace::clean -except => 'meta';

extends 'Socialtext::Base';

sub class_id { 'account_factory' }

sub create {
    my $self = shift;
    my %p    = @_;

    my $acct = Socialtext::Account->create( %p );

    $self->hub->pluggable->hook('nlw.finish_account_create', $acct);

    return $acct;
}

no Moose;
__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
1;
