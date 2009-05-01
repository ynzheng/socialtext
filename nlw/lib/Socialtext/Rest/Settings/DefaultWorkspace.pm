package Socialtext::Rest::Settings::DefaultWorkspace;
# @COPYRIGHT@
use Moose;
use Socialtext::AppConfig;
use Socialtext::Exceptions;
use Socialtext::Workspace;
use Socialtext::HTTP qw/:codes/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::Workspace';

sub _new_workspace {
    my $self = shift;
    return ( $self->ws )
        ? Socialtext::Workspace->new( name => $self->ws )
        : Socialtext::NoWorkspace->new();
}

sub ws { 
    my ($self, $rest) = shift;
    my $name = Socialtext::AppConfig->default_workspace;

    Socialtext::Exception->throw(
        error => "Default Workspace not found.",
        http_status => HTTP_404_Not_Found
    ) unless $name;

    return $name;
}

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
1;

