# @COPYRIGHT@
package Socialtext::Helpers;
use strict;
use warnings;
use Encode;

# vaguely akin to RubyOnRails' "helpers"
use Socialtext;
use base 'Socialtext::Base';
use Socialtext::Appliance::Config;
use Socialtext::Search::Config;
use Socialtext::Search::Set;
use Socialtext::TT2::Renderer;
use Socialtext::l10n qw/loc/;
use Socialtext::Stax;
use Socialtext::Timer;
use Socialtext::String ();
use Apache::Cookie;
use Email::Address;
use Email::Valid;

my $PROD_VERSION = Socialtext->product_version;
my $CODE_BASE = Socialtext::AppConfig->code_base;

sub class_id { 'helpers' }

sub static_path { "/static/$PROD_VERSION" }

my $supported_format = {
    'en' => '%B %Y',
    'ja' => '%Y年 %m月',
};

sub _get_date_format {
    my $self = shift;
    my $locale = $self->hub->best_locale;
    my $locale_format = $supported_format->{$locale};
    if (!defined $locale_format) {
        $locale = 'en';
        $locale_format = $supported_format->{'en'};
    }

    return DateTime::Format::Strptime->new(
        pattern=> $locale_format,
        locale => $locale,
    );
}

sub format_date {
    my $self = shift;
    my $year = shift;
    my $month = shift;

    # Create DateTime object
    my $datetime = DateTime->new(
        time_zone => 'local',
        year => $year,
        month => $month,
        day => 1,
        hour => 0,
        minute => 0,
        second => 0
    );

    my $format = $self->_get_date_format;
    my $date_str = $format->format_datetime($datetime);
    Encode::_utf8_on($date_str);
    return $date_str;
}


# XXX most of this should become Socialtext::Links or something

sub full_script_path {
    my $self = shift;
    '/' . $self->hub->current_workspace->name . '/index.cgi'
}

sub script_path { 'index.cgi' }

sub query_string_from_hash {
    my $self = shift;
    my %query = @_;
    return %query
      ? join '', map { ";$_=$query{$_}" } keys %query
      : '';
}

# XXX need to refactor the other stuff in this file to use this
sub script_link {
    my $self = shift;
    my $label = shift;
    my %query = @_;
    my $url = $self->script_path . '?' . $self->query_string_from_hash(%query);
    return qq(<a href="$url">$label</a>);
}

sub page_display_link {
    my $self = shift;
    my $name = shift;
    my $page = $self->hub->pages->new_from_name($name);
    return $self->page_display_link_from_page($page);
}

sub page_display_link_from_page {
    my $self = shift;
    my $page = shift;
    my $path = $self->script_path . '?' . $page->uri;
    my $title = $self->html_escape($page->metadata->Subject);
    return qq(<a href="$path">$title</a>);
}

sub page_edit_link {
    my $self = shift;
    my $page_name = shift;
    my $link_text = shift;
    my $extra = $self->query_string_from_hash(@_);
    return
        '<a href="' . $self->page_edit_path($page_name) . $extra . '">'
        . $self->html_escape($link_text)
        . '</a>';
}

sub page_display_path {
    my $self = shift;
    my $page_name = shift;
    my $path = $self->script_path();
    return $path . '?' . $page_name;
}

sub page_edit_path {
    my $self = shift;
    my $page_name = shift;
    my $path = $self->script_path();
    return $path . '?' . $self->page_edit_params($page_name)
}

# ...aaand we need this one, too.
sub page_edit_params {
    my $self = shift;
    my $page_name = shift;
    return 'action=display;page_name='
        . $self->uri_escape($page_name)
        . ';js=show_edit_div'
}

sub preference_path {
    my $self = shift;
    my $pref = shift;
    $self->script_path
        . "?action=preferences_settings;preferences_class_id=$pref"
        . $self->query_string_from_hash(@_)
}

sub _get_workspace_list_for_template {
    my $self = shift;
    return $self->{_workspacelist} if $self->{_workspacelist};

    my @workspaces = 
    return $self->{_workspacelist} = [
        sort { lc($a->{label}) cmp lc($b->{label})} 
        map {+{
            label => $_->title,
            name => $_->name,
            account => $_->account->name,
            id => $_->workspace_id,
        }} $self->hub->current_user->workspaces->all
    ];
}

sub default_workspace {
    my $self = shift;
    require Socialtext::Workspace;      # lazy-load, to reduce startup impact
    my $ws = Socialtext::Workspace->Default;

    return ( defined $ws && $ws->has_user( $self->hub->current_user ) )
        ? { label => $ws->title, link => "/" . $ws->name }
        : undef;
}

sub signals_only {
    my $self = shift;

    # Appliance Code is probably not installed if there's an error.
    eval "require Socialtext::Appliance::Config";
    if ( my $e = $@ ) {
        st_log( 'info', "Could not load Socialtext::Appliance::Config: $e\n" );
        return 0;
    }

    my $config = Socialtext::Appliance::Config->new;
    return $config->value('signals_only');
}

sub _get_history_list_for_template
{
    my $self = shift;

    my $history = $self->hub->breadcrumbs->get_crumbs;
   
    my @historylist =
        map { +{ label => $_->{page_title}, link => $_->{page_full_uri} }; }
        @$history;
    if ($#historylist > 19) { $#historylist = 19;}
    return  \@historylist;
}

sub global_template_vars {
    my $self = shift;

    Socialtext::Timer->Continue('global_tt2_vars');

    my $cur_ws = $self->hub->current_workspace;
    my $cur_user = $self->hub->current_user;

    my $show_search_set = (
        ( $cur_user->is_authenticated )
            || ( $cur_user->is_guest
            && Socialtext::AppConfig->interwiki_search_set )
    );
    my $snippet = Socialtext::Search::Config->new()->search_box_snippet;

    my $renderer = Socialtext::TT2::Renderer->instance();

    my $search_box = $renderer->render(
        template => \$snippet,
        paths => $self->hub->skin->template_paths,
        vars => {
            current_workspace => $cur_ws,
            show_search_set   => $show_search_set,
            search_sets       => [Socialtext::Search::Set->AllForUser(
                $cur_user
            )->all],
        }
    );

    my $plugins_enabled = [
        map { $_->name }
        grep {
            $cur_ws->is_plugin_enabled($_->name) ||
            $cur_user->can_use_plugin($_->name)
        } Socialtext::Pluggable::Adapter->plugins
    ];
    
    my $plugins_enabled_for_current_workspace_account = [
        map { $_->name }
        grep {
            $cur_ws->account->is_plugin_enabled($_->name)
        } Socialtext::Pluggable::Adapter->plugins
    ];
    
    my $logo = $self->hub->skin->dynamic_logo;

    my $cookies = {};
    eval { $cookies = Apache::Cookie->fetch() };

    my $locale = $self->hub->display->preferences->locale;
    my %result = (
        firebug           => $self->hub->rest->query->param('firebug') || 0,
        action            => $self->hub->cgi->action,
        pluggable         => $self->hub->pluggable,
        loc               => \&loc,
        loc_lang          => ($locale ? $locale->value : undef),
        css               => $self->hub->skin->css_info,
        user              => $self->_get_user_info,
        wiki              => $self->_get_wiki_info,
        checker           => $self->hub->checker,
        current_workspace => $cur_ws,
        current_page      => $self->hub->pages->current,
        home_is_dashboard =>
            $cur_ws->homepage_is_dashboard,
        homepage_weblog =>
            $cur_ws->homepage_weblog,
        workspace_present  => $cur_ws->real,
        customjs           => $self->hub->skin->customjs,
        app_version        => Socialtext->product_version,
        skin_name          => $self->hub->skin->skin_name,
        search_box_snippet => $search_box,
        miki_url           => $self->miki_path,
        stax_info          => $self->hub->stax->hacks_info,
        workspaceslist     => $self->_get_workspace_list_for_template,
        default_workspace  => $self->default_workspace,
        ui_is_expanded     => defined($cookies->{"ui_is_expanded"}),
        plugins_enabled    => $plugins_enabled,
        plugins_enabled_for_current_workspace_account => $plugins_enabled_for_current_workspace_account,
        self_registration  => Socialtext::AppConfig->self_registration(),
        time               => time,
        dynamic_logo_url   => $logo,
        $self->hub->pluggable->hooked_template_vars,
        locking_enabled       => $self->hub->current_workspace->allows_page_locking,
        can_lock              => $self->hub->checker->check_permission('lock'),
        page_locked           => $self->hub->pages->current->locked,
        page_locked_for_user  => 
            $self->hub->pages->current->locked && 
            $self->hub->current_workspace->allows_page_locking &&
            !$self->hub->checker->check_permission('lock'),
        role_for_user      => $cur_ws->role_for_user(user=>$cur_user) || undef,
        signals_only       => $self->signals_only,
    );

    # We're disabling the history global nav functionality for now, until its
    # truly global (cross workspace)
#     if ($cur_ws->real) {
#         $result{history} = $self->_get_history_list_for_template; 
#     }

    $result{is_workspace_admin}=1 if ($self->hub->checker->check_permission('admin_workspace'));

    Socialtext::Timer->Pause('global_tt2_vars');

    return %result;
}

sub miki_path {
    my ($self, $link) = @_;
    require Socialtext::Formatter::LiteLinkDictionary;

    my $miki_path      = '/lite/workspace_list';
    my $page_name      = $self->hub->pages->current->name;
    my $workspace_name = $self->hub->current_workspace->name;

    if ($workspace_name) {
        $miki_path = Socialtext::Formatter::LiteLinkDictionary->new->format_link(
            link => $link || 'interwiki',
            workspace => $workspace_name,
            page_uri  => $page_name,
            );
    }
    return $miki_path;
}

sub _get_user_info {
    my ($self) = @_;
    my $user = $self->hub->current_user;
    return {
        username           => $user->guess_real_name,
        userid             => $user->username,
        email_address      => $user->email_address,
        is_guest           => $user->is_guest,
        is_business_admin  => $user->is_business_admin,
        primary_account_id => $user->primary_account_id,
        accounts           => sub {
            return [
                map {+{
                    account_id => $_->account_id,
                    name => $_->name,
                    plugins => [$_->plugins_enabled],
                }} $user->accounts
            ],
        },
        can_use_plugin     => sub {
            $user->can_use_plugin(@_);
        },
    };
}

# This function is called in the ControlPanel
sub skin_uri { 
    my $skin_name  = shift;
    my $skin = Socialtext::Skin->new(name => $skin_name);
    return $skin->skin_uri();
}

sub _get_wiki_info {
    my ($self) = @_;
    my $wiki = $self->hub->current_workspace;
    my $skin = $self->hub->skin->skin_name;

    return {
        title         => $wiki->title,
        central_page  => Socialtext::String::title_to_id( $wiki->title ),
        logo          => $wiki->logo_uri_or_default,
        name          => $wiki->name,
        has_dashboard => $wiki->homepage_is_dashboard,
        is_public     => $wiki->permissions->is_public,
        uri           => $wiki->uri,
        skin          => $skin,
        email_address => $wiki->email_in_address,
        static_path   => $self->static_path,
        skin_uri      => \&skin_uri,
        comment_form_window_height => $wiki->comment_form_window_height,
        system_status              => $self->hub->main ?
            $self->hub->main->status_message() : undef,
        comment_by_email           => $wiki->comment_by_email,
        email_in_address           => $wiki->email_in_address,
    };
}

sub validate_email_addresses {
    my $self = shift;
    my @emails;
    my @invalid;
    if ( my $ids = shift ) {
        my @lines = $self->_split_email_addresses( $ids );

        unless (@lines) {
            $self->add_error(loc("No email addresses specified"));
            return;
        }

        for my $line (@lines) {
            my ( $email, $first_name, $last_name )
              = $self->_parse_email_address($line);
            unless ($email) {
                push @invalid, $line;
                next;
            }

            push @emails, {
                email_address => $email,
                first_name => $first_name,
                last_name => $last_name,
            }
        }
    }
    else
    {
        push @invalid, loc("No email addresses specified");
    }

    return(\@emails, \@invalid);
}

sub _split_email_addresses {
    my $self = shift;
    return grep /\S/, split(/[,\r\n]+\s*/, $_[0]);
}

sub _parse_email_address {
    my $self = shift;
    my $email = shift;

    return unless defined $email;

    my ($address) = Email::Address->parse($email);
    return unless $address;

    my ( $first, $last );
    if ( grep { defined && length } $address->name ) {
        my $name = $address->name;
        $name =~ s/^\s+|\s+$//g;

        ( $first, $last ) = split /\s+/, $name, 2;
    }

    return lc $address->address, $first, $last;
}

1;
