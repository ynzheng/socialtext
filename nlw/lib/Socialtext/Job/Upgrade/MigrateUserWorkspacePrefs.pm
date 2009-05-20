package Socialtext::Job::Upgrade::MigrateUserWorkspacePrefs;
# @COPYRIGHT@
use Moose;
use Socialtext::Paths;
use Socialtext::Workspace::Importer;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

sub do_work {
    my $self = shift;

    my $path = Socialtext::Paths::user_directory($self->workspace->name);
    Socialtext::Workspace::Importer->Import_user_workspace_prefs($path, $self->workspace);

    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;
