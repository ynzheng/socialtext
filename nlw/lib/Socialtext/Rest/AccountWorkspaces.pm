package Socialtext::Rest::AccountWorkspaces;
# @COPYRIGHT@

use Moose;
use Socialtext::Account;
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::Collection';

sub permission { +{ GET => undef } }
sub collection_name { "Account Workspaces" }

sub _entities_for_query {
    my $self      = shift;
    my $rest      = $self->rest;
    my $user      = $rest->user;
    my $query     = $rest->query->param('q') || '';
    my $acct_name = $self->acct();
    my $account   = Socialtext::Account->new( name => $acct_name );

    return () unless $account;

    my @workspaces = $account->workspaces()->all();

    if ( $user->is_business_admin && $query eq 'all' ) {
        return @workspaces;
    }

    return grep { $_->has_user( $user ) } @workspaces;
}

sub _entity_hash {
    my $self      = shift;
    my $workspace = shift;

    return +{
        name  => $workspace->name,
        uri   => '/data/workspaces/' . $workspace->name,
        title => $workspace->title,
        modified_time => $workspace->creation_datetime,
        id => $workspace->workspace_id,
    };
}

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
1;
