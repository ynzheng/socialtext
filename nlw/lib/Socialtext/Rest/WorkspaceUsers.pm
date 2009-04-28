package Socialtext::Rest::WorkspaceUsers;
# @COPYRIGHT@

use warnings;
use strict;

use base 'Socialtext::Rest::Users';
use Socialtext::JSON;
use Socialtext::HTTP ':codes';
use Socialtext::WorkspaceInvitation;
use Socialtext::User::Find::Workspace;

# FIXME: POST is not yet implemented
#sub allowed_methods {'GET, HEAD, POST'}
sub allowed_methods {'GET, HEAD, POST'}
sub collection_name { "Users in workspace " . $_[0]->ws }

sub _entity_hash {
    my ( $self, $user ) = @_;
    my $name  = $user->username;
    my $email = $user->email_address;
    return +{
        name               => $name,
        email              => $email,
        uri                => "/data/users/$name",
    };
}

sub create_user_find {
    my $self = shift;
    my $limit = $self->rest->query->param('count') ||
                $self->rest->query->param('limit') ||
                25;
    my $offset = $self->rest->query->param('offset') || 0;

    my $filter = $self->rest->query->param('filter');
    my $workspace = Socialtext::Workspace->new( name => $self->ws );
    die "invalid workspace" unless $workspace;

    return Socialtext::User::Find::Workspace->new(
        viewer => $self->rest->user,
        limit => $limit,
        offset => $offset,
        filter => $filter,
        workspace => $workspace,
    )
}

sub if_authorized {
    my $self = shift;
    my $method = shift;
    my $call = shift;

    my $acting_user = $self->rest->user;

    if ($method eq 'POST') {
        return $self->not_authorized 
            unless $self->rest->user->is_business_admin()
                || $self->rest->user->is_technical_admin()
                || $self->hub->checker->check_permission('admin_workspace');
    }
    elsif ($method eq 'GET') {
        my $can_admin = $self->workspace->permissions->user_can(
            user       => $acting_user,
            permission =>
                Socialtext::Permission->new( name => 'admin_workspace' ),
        );
        # REVIEW: {bz: 1265} requires everybody with "Email this Page"
        # permission to see the workspace user list.  Is this desired?
        my $can_email = $self->workspace->permissions->user_can(
            user       => $acting_user,
            permission =>
                Socialtext::Permission->new( name => 'email_out' ),
        );
        return $self->not_authorized unless $can_admin or $can_email;
    }
    else {
        return $self->bad_method;
    }

    return $self->$call(@_);
}

sub POST {
    my $self = shift;
    return $self->if_authorized('POST', '_POST', @_);
}

sub _POST {
    my $self = shift;
    my $rest = shift;

    my $create_request_hash = decode_json( $rest->getContent() );

    unless ( $create_request_hash->{username} and
             $create_request_hash->{rolename} ) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
            -type  => 'text/plain', );
        return "username, rolename required";
    }

    my $workspace_name = $self->ws;
    my $username = $create_request_hash->{username};
    my $rolename = $create_request_hash->{rolename};

    my $workspace = Socialtext::Workspace->new( name => $workspace_name );
    
    unless( $workspace ) {
        return $self->no_workspace();
    }

    eval {
        if ( $create_request_hash->{send_confirmation_invitation} ) {
            my $from_user = $self->rest->user;
            my $username = $create_request_hash->{username};
            die "username is required\n" unless $username;
            if ( $create_request_hash->{from_address} ) {
                my $from_address = $create_request_hash->{from_address};
                $from_user =
                  Socialtext::User->new( email_address => $create_request_hash->{from_address} );
                die "from_address: $from_address must be valid Socialatext user\n"
                  unless $from_user;
            }
            my $invitation =
              Socialtext::WorkspaceInvitation->new( workspace => $workspace,
                                                    from_user => $from_user,
                                                    invitee   => $username );
            $invitation->send( );
        } else {
            my $user = Socialtext::User->new( username => $username );
            my $role = Socialtext::Role->new( name => $rolename );
        
            unless( $user && $role ) {
                die "both username, rolename must be valid\n";
            }
        
            $workspace->add_user( user => $user,
                                  role => $role );
            $workspace->assign_role_to_user( user => $user, role => $role, is_selected => 1 );
        }
    };
    
    if ( my $e = Exception::Class->caught('Socialtext::Exception::DataValidation') ) {
        $rest->header(
                      -status => HTTP_400_Bad_Request,
                      -type   => 'text/plain' );
        return join( "\n", $e->messages );
    } elsif ( $@ ) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
            -type   => 'text/plain' );
        # REVIEW: what kind of system logging should we be doing here?
        return "$@";
    }


    $rest->header(
        -status => HTTP_201_Created,
        -type   => 'application/json',
        -Location => $self->full_url('/', ''),
    );

    return '';
}

1;
