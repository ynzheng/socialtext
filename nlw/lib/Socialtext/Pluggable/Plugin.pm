package Socialtext::Pluggable::Plugin;
# @COPYRIGHT@
use strict;
use warnings;

use Socialtext;
use Socialtext::HTTP ':codes';
use Socialtext::TT2::Renderer;
use Socialtext::AppConfig;
use Class::Field qw(const field);
use Socialtext::URI;
use Socialtext::Storage;
use Socialtext::AppConfig;
use Socialtext::JSON qw(encode_json);
use Socialtext::User;
use URI::Escape qw(uri_escape);
use Socialtext::Formatter::Parser;
use Socialtext::Cache;
use Socialtext::Authz::SimpleChecker;
use Socialtext::Pluggable::Adapter;
use Socialtext::String ();
use Socialtext::SQL qw(:txn :exec);
use Socialtext::Log qw/st_log/;
my $prod_ver = Socialtext->product_version;

# Class Methods

my %hooks;
my %content_types;
my %rest_hooks;
my %rests;

field hub => -weak;
field 'rest';
field 'declined';

const priority => 100;
const scope => 'account';
const hidden => 1; # hidden to admins
const read_only => 0; # cannot be disabled/enabled in the control panel

sub dependencies { } # Enable/Disable dependencies
sub enables {} # Enable only dependencies

sub reverse_dependencies {
    my $class = shift;
    my @rdeps;
    for my $pclass (Socialtext::Pluggable::Adapter->plugins) {
        for my $dep ($pclass->dependencies) {
            push @rdeps, $pclass->name if $dep eq $class->name;
        }
    }
    return @rdeps;
}

# perldoc Socialtext::URI for arguments
#    path = '' & query => {}

sub uri {
    my $self = shift;
    return $self->hub->current_workspace->uri . Socialtext::AppConfig->script_name;
}

sub default_workspace {
    my $self = shift;
    return $self->hub->helpers->default_workspace;
}

sub base_uri {
    my $self = shift;
    return $self->{_base_uri} if $self->{_base_uri};
    ($self->{_base_uri} = $self->make_uri) =~ s{/$}{};
    return $self->{_base_uri};
}

sub make_uri {
    my $self = shift;
    return Socialtext::URI::uri(@_);
}

sub code_base {
   return Socialtext::AppConfig->code_base;
}

sub query {
    my $self = shift;
    return $self->hub->rest->query;
}

sub query_string {
    my $self = shift;
    return $self->hub->cgi->query_string;
}

sub getContent {
    my $self = shift;
    return $self->hub->rest->getContent;
}

sub getContentPrefs {
    my $self = shift;
    return $self->hub->rest->getContentPrefs;
}

sub user {
    my $self = shift;
    return $self->hub->current_user;
}

sub viewer {
    my $self = shift;
    return $self->hub->viewer;
}

sub username {
    my $self = shift;
    return $self->user->username;
}

sub resolve_user {
    my ($self, $username) = @_;
    my $user = eval { Socialtext::User->Resolve($username) };
    $user->hub($self->hub) if $user and $self->hub and !$user->hub;
    return $user;
}

sub authz {
    my $self = shift;
    return $self->hub ? $self->hub->authz : undef;
}

sub best_full_name {
    my ($self,$username) = @_;
    my $person = eval { Socialtext::User->Resolve($username) };
    return $person
        ? $person->guess_real_name()
        : $username;
}

sub header_out {
    my $self = shift;
    my $rest = $self->rest || $self->hub->rest;
    return $rest->header(@_);
}

sub header_in {
    my $self = shift;
    my $rest = $self->rest || $self->hub->rest;
    if (@_) {
        return $rest->request->header_in(@_);
    }
    else {
        return $rest->request->headers_in;
    }
}

sub current_page {
  my $self = shift;

  return $self->hub->pages->current;
}

sub current_workspace { $_[0]->hub->current_workspace }
sub current_workspace_id { $_[0]->current_workspace->workspace_id }

sub add_rest {
    my ($self,$path,$sub) = @_;
    my $class = ref($self) || $self;
    push @{$rests{$class}}, {
        $path => [ 'Socialtext::Pluggable::Adapter', "_rest_hook_$sub"],
    };
    push @{$rest_hooks{$class}}, {
        method => $sub,
        name => $sub,
        class => $class,
    };
}

sub add_hook {
    my ($self,$hook,$method) = @_;
    my $class = ref($self) || $self;
    push @{$hooks{$class}}, {
        method => $method,
        name => $hook,
        class => $class,
    };
}

sub add_content_type {
    my ($self,$name,$visible_name) = @_;
    my $class = ref($self) || $self;
    my $types = $content_types{$class};
    $visible_name ||= ucfirst $name;
    $content_types{$class}{$name} = $visible_name;
}

sub hooks {
    my $self = shift;
    my $class = ref($self) || $self;
    return $hooks{$class} ? @{$hooks{$class}} : ();
}

sub content_types {
    my $self = shift;
    my $class = ref($self) || $self;
    return $content_types{$class}
}

sub rest_hooks {
    my $self = shift;
    my $class = ref($self) || $self;
    return $rest_hooks{$class} ? @{$rest_hooks{$class}} : ();
}

sub rests {
    my $self = shift;
    my $class = ref($self) || $self;
    return $rests{$class} ? @{$rests{$class}} : ();
}

# Object Methods

sub new {
    my ($class, %args) = @_;
    # TODO: XXX: DPL, not sure what args are required but because the object
    # is actually instantiated deep inside nlw we can't just use that data
    my $self = {
#        %args,
    };
    bless $self, $class;
    $self->{Cache} = Socialtext::Cache->cache('ST::Pluggable::Plugin');
    return $self;
}

sub storage {
    my ($self,$id) = @_;
    die "Id is required for storage\n" unless $id;
    return Socialtext::Storage->new($id, $self->user->user_id);
}

sub name {
    my $self = shift;

    return $self->{_name} if ref $self and $self->{_name};

    my $class = ref $self || $self;
    my $name = $class->_transform_classname(
        sub { lc( shift ) }
    );

    $self->{_name} = $name if ref $self;
    return $name;
}

sub title {
    my $self = shift;

    return $self->{_title} if ref $self and $self->{_title};

    my $class = ref $self || $self;
    my $title = 'Socialtext ' . $class->_transform_classname(
        sub { shift }
    );

    $self->{_title} = $title if ref $self;
    return $title;
}

sub _transform_classname {
    my $self     = shift;
    my $callback = shift;

    ( my $name = ref $self || $self ) =~ s{::}{/}g;

    # Pull off everything from the name up to and including 'Plugin/',
    # if we can't do that, we should just return everything after the last
    # '/'.
    $name =~ s{^.*/}{}
        unless $name =~ s{^.*?/Plugin/}{}; 

    return &$callback( $name );
}

sub plugins {
    my $self = shift;
    # XXX: should the list be limited like this?
    return grep { $self->user->can_use_plugin($_) } $self->all_plugins
}

sub all_plugins {
    return $_[0]->hub->pluggable->plugin_list;
}

sub plugin_dir {
    my $self = shift;
    my $name = shift || $self->name;
    return $self->code_base . "/plugin/$name";
}

sub cgi_vars {
    my $self = shift;
    return $self->hub->cgi->vars;
}

sub full_uri {
    my $self = shift;
    return $self->hub->cgi->full_uri_with_query;
}

sub redirect_to_login {
    my $self = shift;
    my $uri = uri_escape($ENV{REQUEST_URI} || '');

    if (Socialtext::BrowserDetect::is_mobile()) {
        return $self->redirect('/lite/login');
    }

    my $login_uri = Socialtext::AppConfig->logout_redirect_uri;
    return $self->redirect("$login_uri?redirect_to=$uri");
}

sub redirect {
    my ($self,$target) = @_;
    unless ($target =~ /^(https?:|\/)/i or $target =~ /\?/) {
        $target = $self->hub->cgi->full_uri . '?' . $target;
    }

    $self->header_out(
        -status => HTTP_302_Found,
        -Location => $target,
    );
    return;
}

sub is_workspace_admin {
    my $self = shift;
    return $self->hub->checker->check_permission('admin_workspace');
}

sub logged_in {
    my $self = shift;
    return 0 unless $self->hub;
    return !$self->hub->current_user->is_guest();
}

sub share {
    my ($self, $plugin) = @_;
    $plugin ||= $self->name;
    return "/nlw/plugin/$prod_ver/$plugin";
}

sub template_paths {
    my $self = shift;
    $self->{_template_paths} ||= [
        glob($self->code_base . "/plugin/*/template"),
    ];
    return $self->{_template_paths};
}

sub template_render {
    my ($self, $template, %args) = @_;

    $self->header_out('Content-Type' => 'text/html; charset=utf-8');

    my $name = $self->name;
    my $plugin_dir = $self->plugin_dir;

    my $renderer = Socialtext::TT2::Renderer->instance;
    return $renderer->render(
        template => $template,
        paths => [
            @{$self->hub->skin->template_paths},
            @{$self->template_paths},
        ],
        vars => {
            %{$self->template_vars},
            %args,
        },
    );
}

sub _get_pref_list {
    my $self = shift;
    my $prefs = $self->hub->preferences_object->objects_by_class;
    my @pref_list = map {
        $_->{title} =~ s/ /&nbsp;/g;
        $_;
        } grep { $prefs->{ $_->{id} } }
        grep { $_->{id} ne 'search' } # hide search prefs screen
        @{ $self->hub->registry->lookup->plugins };
    return \@pref_list;
}

sub template_vars {
    my $self = shift;
    my %template_vars = $self->hub->helpers->global_template_vars;
    return {
        pref_list => sub {
            $self->_get_pref_list;
        },
        share => $self->share,
        workspaces => [$self->hub->current_user->workspaces->all],
        as_json => sub {
            my $json = encode_json(@_);

            # hack so that json can be included in other <script> 
            # sections without breaking stuff
            $json =~ s!</script>!</scr" + "ipt>!g;

            return $json;
        },
        %template_vars,
    }
}

sub created_at {
    my $self = shift;
    my %p = (
        workspace_name => undef,
        page_name => undef,
        @_
    );

    my $page = $self->get_page(%p);
    return undef if (!defined($page));
    my $original_revision = $page->original_revision;
    return $original_revision->datetime_for_user;
}

sub created_by {
    my $self = shift;
    my %p = (
        workspace_name => undef,
        page_name => undef,
        @_
    );

    my $page = $self->get_page(%p);
    return undef if (!defined($page));
    my $original_revision = $page->original_revision;
    return $original_revision->last_edited_by;
}

sub get_revision {
    my $self = shift;
    my %p = (
        workspace_name => undef,
        page_name => undef,
        revision_id => undef,
        @_
    );

    return undef if (!$p{workspace_name} || !$p{revision_id} || !$p{page_name});

    my $page_id = Socialtext::String::title_to_id($p{page_name});
    my $cache_key = "page $p{workspace_name} $page_id revision $p{revision_id}";
    my $revision = $self->value_from_cache($cache_key);
    return $revision if ($revision);

    my $workspace = Socialtext::Workspace->new( name => $p{workspace_name} );
    return undef if (!defined($workspace));
    my $auth_check = Socialtext::Authz::SimpleChecker->new(
        user => $self->hub->current_user,
        workspace => $workspace,
    );
    my $hub = $self->_hub_for_workspace($workspace);
    return undef unless defined($hub);
    if ($auth_check->check_permission('read')) {
        $revision = $hub->pages->new_page($page_id);
        $revision->revision_id($p{revision_id});
        $self->cache_value(
            key => $cache_key,
            value => $revision,
        );
    }
    else {
        return undef;
    }
    return $revision;
}

sub get_page {
    my $self = shift;
    my %p = (
        workspace_name => undef,
        page_name => undef,
        @_
    );

    return undef if (!$p{workspace_name} || !$p{page_name});

    my $page_id = Socialtext::String::title_to_id($p{page_name});
    my $cache_key = "page $p{workspace_name} $page_id";
    my $page = $self->value_from_cache($cache_key);
    return $page if ($page);

    my $workspace = Socialtext::Workspace->new( name => $p{workspace_name} );
    return undef if (!defined($workspace));
    my $auth_check = Socialtext::Authz::SimpleChecker->new(
        user => $self->hub->current_user,
        workspace => $workspace,
    );
    my $hub = $self->_hub_for_workspace($workspace);
    return undef unless defined($hub);
    if ($auth_check->check_permission('read')) {
        $page = $hub->pages->new_page($page_id);
        $self->cache_value(
            key => $cache_key,
            value => $page,
        );
    }
    else {
        return undef;
    }
    return $page;
}

sub name_to_id {
    my $self = shift;
    return Socialtext::String::title_to_id(shift);
}

sub _hub_for_workspace {
    my ( $self, $workspace ) = @_;

    my $hub = $self->hub;
    if ( $workspace->name ne $self->hub->current_workspace->name ) {
        $hub = $self->value_from_cache('hub ' . $workspace->name);
        if (!$hub) {
            my $main = Socialtext->new();
            $main->load_hub(
                current_user      => $self->hub->current_user,
                current_workspace => $workspace
            );
            $main->hub->registry->load;

            $hub = $main->hub;
            $self->cache_value(
                key => 'hub ' . $workspace->name,
                value => $hub,
            );
        }
    }

    return $hub;
}

sub cache_value {
    my $self = shift;
    my %p = (
        key => undef,
        value => undef,
        @_
    );

    $self->{Cache}->set($p{key}, $p{value});
}

sub value_from_cache {
    my $self = shift;
    my $key = shift;

    return $self->{Cache}->get($key);
}

sub tags_for_page {
    my $self = shift;
    my %p = (
        page_name => undef,
        workspace_name => undef,
        @_
    );

    my @tags = ();
    my $page = $self->get_page(%p);
    if (defined($page)) {
        push @tags, @{$page->metadata->Category};
    }
    return ( grep { lc($_) ne 'recent changes' } @tags );
}

sub search {
    my $self = shift;
    my %p = (
        search_term => undef,
        sortby => 'Relevance',
        @_
    );

    $p{sortby} ||= 'Relevance';
    $self->hub->search->sortby( $p{sortby} );
    # load the search result which may or may not be cached.
    my $set =  $self->hub->search->get_result_set(
       search_term => $p{search_term},
       scope       => '_',
    );
    my $rset = $self->hub->search->result_set($set);
    return $rset;
}

sub is_hook_enabled {
    my $self = shift;
    my $hook_name = shift; # throw away here
    if ($self->scope eq 'always') {
        return 1;
    }
    elsif ($self->scope eq 'workspace') {
        my $ws = $self->hub ? $self->hub->current_workspace : undef;
        return 1 if $ws and  $ws->real and $ws->is_plugin_enabled($self->name);
    }
    elsif ($self->scope eq 'account') {
        my $user;
        eval {
            $user = $self->hub ? $self->hub->current_user : $self->rest->user;
        };
        return $user->can_use_plugin($self->name) if $user;
    }
    else {
        die 'Unknown scope: ' . $self->scope;
    }
}

sub format_link {
    my ($self, $link, %args) = @_;
    return $self->hub->viewer->link_dictionary->format_link(
        link => $link,
        url_prefix => $self->base_uri,
        %args,
    );
}

# grants access to the low-level Apache::Request
sub request {
    my $self = shift;
    my $rest = $self->rest || $self->hub->rest;
    return $rest->request;
}

# Workspace Plugin Prefs

sub set_workspace_prefs {
    my ($self, %prefs) = @_;
    my $workspace_id = $self->current_workspace_id || die "No workspace";
    my $plugin = $self->name;

    return unless %prefs;

    my $qs = join ', ', ('?') x keys %prefs;

    sql_begin_work;

    eval {
        sql_execute("
            DELETE
              FROM workspace_plugin_pref
             WHERE workspace_id = ?
               AND plugin = ?
               AND key IN ($qs)
        ", $workspace_id, $plugin, keys %prefs);

        my @columns;
        for my $key (keys %prefs) {
            push @{$columns[0]}, $workspace_id;
            push @{$columns[1]}, $plugin;
            push @{$columns[2]}, $key;
            push @{$columns[3]}, $prefs{$key};
        }

        sql_execute_array('
            INSERT INTO workspace_plugin_pref (
                workspace_id, plugin, key, value
            ) VALUES (?, ?, ?, ?)
        ', {}, @columns);
    };
    if (my $error = $@) {
        sql_rollback;
        die $error;
    }
    sql_commit;

    my $username  = $self->hub->current_user->username;
    my $wksp_name = $self->hub->current_workspace->name;
    st_log()->info("$username changed $plugin preferences for $wksp_name");
}

sub get_workspace_prefs {
    my $self = shift;
    my $workspace_id = $self->current_workspace_id || die "No workspace";
    my $sth = sql_execute('
        SELECT key, value
          FROM workspace_plugin_pref
         WHERE workspace_id = ?
           AND plugin = ?
    ', $workspace_id, $self->name);
    my %res;
    while (my $row = $sth->fetchrow_hashref) {
        $res{$row->{key}} = $row->{value};
    }
    return \%res;
}

sub clear_workspace_prefs {
    my $self = shift;
    my $workspace_id = $self->current_workspace_id || die "No workspace";
    my $plugin = $self->name;

    sql_execute('
        DELETE FROM workspace_plugin_pref
         WHERE workspace_id = ?
           AND plugin = ?
    ', $workspace_id, $plugin);

    my $username  = $self->hub->current_user->username;
    my $wksp_name = $self->hub->current_workspace->name;
    st_log()->info("$username cleared $plugin preferences for $wksp_name");
}

# User Plugin Prefs

sub set_user_prefs {
    my ($self, %prefs) = @_;
    my $user_id = $self->hub->current_user->user_id || die "No user";
    my $plugin = $self->name;

    my $qs = join ', ', ('?') x keys %prefs;

    sql_begin_work;

    eval {
        sql_execute("
            DELETE
              FROM user_plugin_pref
             WHERE user_id = ?
               AND plugin = ?
               AND key IN ($qs)
        ", $user_id, $plugin, keys %prefs);

        my @columns;
        for my $key (keys %prefs) {
            push @{$columns[0]}, $user_id;
            push @{$columns[1]}, $plugin;
            push @{$columns[2]}, $key;
            push @{$columns[3]}, $prefs{$key};
        }

        sql_execute_array('
            INSERT INTO user_plugin_pref (
                user_id, plugin, key, value
            ) VALUES (?, ?, ?, ?)
        ', {}, @columns);
    };
    if (my $error = $@) {
        sql_rollback;
        die $error;
    }
    sql_commit;

    my $username  = $self->hub->current_user->username;
    st_log()->info("$username changed their $plugin plugin preferences");
}

sub get_user_prefs {
    my $self = shift;
    my $user_id = $self->hub->current_user->user_id || die "No user";
    my $sth = sql_execute('
        SELECT key, value
          FROM user_plugin_pref
         WHERE user_id = ?
           AND plugin = ?
    ', $user_id, $self->name);
    my %res;
    while (my $row = $sth->fetchrow_hashref) {
        $res{$row->{key}} = $row->{value};
    }
    return \%res;
}

sub export_user_prefs {
    my $self = shift;
    my $hash = shift;

    $hash->{$self->name} = $self->get_user_prefs();
}

sub import_user_prefs {
    my $self = shift;
    my $hash = shift;

    if (my $prefs = $hash->{$self->name}) {
        if (ref($prefs) eq 'HASH' and keys %$prefs) {
            $self->set_user_prefs(%$prefs);
        }
    }
}

1;
