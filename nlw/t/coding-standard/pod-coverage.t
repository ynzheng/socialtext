#!perl
# @COPYRIGHT@
use warnings;
use strict;
use Test::More;

eval "use Test::Pod::Coverage 1.00";
plan skip_all => 'Test::Pod::Coverage 1.00 required for testing POD coverage' if $@;

###############################################################################
# TODO: modules that have insufficient POD coverage, but that we'd like to
# eventually get brought out of the dark ages.  For now they're all marked as
# "TODO" tests.
#
# Yes, this is a *HUGE* list.  We really should either make POD for these or
# explicitly state that "we're _not_ going to make POD for these".
my %ToDoModules = map { $_ => 1 } qw(
    Apache::Session::Store::Postgres::Socialtext
    Socialtext
    Socialtext::AccessHandler::IsBusinessAdmin
    Socialtext::AccountInvitation
    Socialtext::AccountLogo
    Socialtext::Apache::Authen::NTLM
    Socialtext::ApacheDaemon
    Socialtext::Attachment
    Socialtext::Attachments
    Socialtext::AttachmentsUIPlugin
    Socialtext::Authen
    Socialtext::BacklinksPlugin
    Socialtext::Base
    Socialtext::Bootstrap::OpenLDAP
    Socialtext::BreadCrumbsPlugin
    Socialtext::BugsPlugin
    Socialtext::Build
    Socialtext::Build::ConfigureValues
    Socialtext::CGI
    Socialtext::CGI::Scrubbed
    Socialtext::CLI
    Socialtext::CategoryPlugin
    Socialtext::Challenger
    Socialtext::Challenger::OpenId
    Socialtext::Challenger::STLogin
    Socialtext::CommentUIPlugin
    Socialtext::CredentialsExtractor
    Socialtext::DaemonUtil
    Socialtext::Date
    Socialtext::Date::l10n
    Socialtext::Date::l10n::en
    Socialtext::Date::l10n::ja
    Socialtext::DeletePagePlugin
    Socialtext::DevEnvPlugin
    Socialtext::DisplayPlugin
    Socialtext::DuplicatePagePlugin
    Socialtext::EditPlugin
    Socialtext::EmailNotifier
    Socialtext::EmailNotifyPlugin
    Socialtext::EmailPageUIPlugin
    Socialtext::EmailReceiver::Base
    Socialtext::EmailReceiver::Factory
    Socialtext::EmailReceiver::en
    Socialtext::EmailReceiver::ja
    Socialtext::EmailSender::Base
    Socialtext::EmailSender::Factory
    Socialtext::EmailSender::en
    Socialtext::EmailSender::ja
    Socialtext::Encode
    Socialtext::Events
    Socialtext::Events::Recorder
    Socialtext::Events::Reporter
    Socialtext::Exceptions
    Socialtext::FavoritesPlugin
    Socialtext::FetchRSSPlugin
    Socialtext::File
    Socialtext::File::Stringify::Default
    Socialtext::File::Stringify::application_msword
    Socialtext::File::Stringify::application_pdf
    Socialtext::File::Stringify::application_postscript
    Socialtext::File::Stringify::application_vnd_ms_excel
    Socialtext::File::Stringify::application_vnd_ms_powerpoint
    Socialtext::File::Stringify::application_zip
    Socialtext::File::Stringify::audio_mpeg
    Socialtext::File::Stringify::text_html
    Socialtext::File::Stringify::text_plain
    Socialtext::File::Stringify::text_rtf
    Socialtext::File::Stringify::text_xml
    Socialtext::FillInFormBridge
    Socialtext::Formatter
    Socialtext::Formatter::AbsoluteLinkDictionary
    Socialtext::Formatter::Block
    Socialtext::Formatter::LiteLinkDictionary
    Socialtext::Formatter::Phrase
    Socialtext::Formatter::RESTLinkDictionary
    Socialtext::Formatter::RailsDemoLinkDictionary
    Socialtext::Formatter::SharepointLinkDictionary
    Socialtext::Formatter::SkinLinkDictionary
    Socialtext::Formatter::Unit
    Socialtext::Formatter::Viewer
    Socialtext::Formatter::WaflBlock
    Socialtext::Formatter::WaflPhrase
    Socialtext::HTMLArchive
    Socialtext::HTTP
    Socialtext::Handler
    Socialtext::Handler::Authen
    Socialtext::Handler::ControlPanel
    Socialtext::Handler::REST
    Socialtext::Handler::URIMap
    Socialtext::Headers
    Socialtext::Helpers
    Socialtext::HitCounterPlugin
    Socialtext::HomepagePlugin
    Socialtext::Hub
    Socialtext::Image
    Socialtext::Indexes
    Socialtext::InitFunctions
    Socialtext::InitHandler
    Socialtext::Job
    Socialtext::Job::AttachmentIndex
    Socialtext::Job::Cmd
    Socialtext::Job::EmailNotify
    Socialtext::Job::PageIndex
    Socialtext::Job::Test
    Socialtext::Job::Upgrade::MigrateUserWorkspacePrefs
    Socialtext::Job::WatchlistNotify
    Socialtext::Job::WeblogPing
    Socialtext::JobCreator
    Socialtext::Jobs
    Socialtext::LDAP
    Socialtext::LDAP::Config
    Socialtext::LDAP::Operations
    Socialtext::Locales
    Socialtext::Log
    Socialtext::MLDBMAccess
    Socialtext::MassAdd
    Socialtext::Migration::Utils
    Socialtext::ModPerl
    Socialtext::Model::Page
    Socialtext::Model::Pages
    Socialtext::MultiPlugin
    Socialtext::NewFormPagePlugin
    Socialtext::OpenIdPlugin
    Socialtext::Page
    Socialtext::Page::Base
    Socialtext::Page::TablePopulator
    Socialtext::PageActivityPlugin
    Socialtext::PageAnchorsPlugin
    Socialtext::PageMeta
    Socialtext::Pages
    Socialtext::Pageset
    Socialtext::Paths
    Socialtext::PdfExport::LinkDictionary
    Socialtext::PdfExportPlugin
    Socialtext::PerfData
    Socialtext::Pluggable::Adapter
    Socialtext::Pluggable::Plugin
    Socialtext::Pluggable::Plugin::Default
    Socialtext::Pluggable::Plugin::Test
    Socialtext::Pluggable::Plugin::Widgets
    Socialtext::Pluggable::WaflPhrase
    Socialtext::Pluggable::WaflPhraseDiv
    Socialtext::Plugin
    Socialtext::PreferencesPlugin
    Socialtext::ProvisionPlugin
    Socialtext::Query::CGI
    Socialtext::Query::Plugin
    Socialtext::Query::Wafl
    Socialtext::RecentChangesPlugin
    Socialtext::RefcardPlugin
    Socialtext::Registry
    Socialtext::RenamePagePlugin
    Socialtext::RequestContext
    Socialtext::Rest
    Socialtext::Rest::AccountLogo
    Socialtext::Rest::AccountUsers
    Socialtext::Rest::Accounts
    Socialtext::Rest::App
    Socialtext::Rest::Attachment
    Socialtext::Rest::Attachments
    Socialtext::Rest::Backlinks
    Socialtext::Rest::BreadCrumbs
    Socialtext::Rest::Challenge
    Socialtext::Rest::Collection
    Socialtext::Rest::Comments
    Socialtext::Rest::Echo
    Socialtext::Rest::Entity
    Socialtext::Rest::Events
    Socialtext::Rest::Events::Activities
    Socialtext::Rest::Events::Awesome
    Socialtext::Rest::Events::Conversations
    Socialtext::Rest::Events::Followed
    Socialtext::Rest::Events::Page
    Socialtext::Rest::EventsBase
    Socialtext::Rest::Feed
    Socialtext::Rest::Frontlinks
    Socialtext::Rest::Help
    Socialtext::Rest::HomePage
    Socialtext::Rest::Hydra
    Socialtext::Rest::Jobs
    Socialtext::Rest::Links
    Socialtext::Rest::Lite
    Socialtext::Rest::Log
    Socialtext::Rest::Page
    Socialtext::Rest::PageAttachments
    Socialtext::Rest::PageRevision
    Socialtext::Rest::PageRevisions
    Socialtext::Rest::PageTagHistory
    Socialtext::Rest::PageTags
    Socialtext::Rest::Pages
    Socialtext::Rest::ReportAdapter
    Socialtext::Rest::Sections
    Socialtext::Rest::Settings::DefaultWorkspace
    Socialtext::Rest::Tag
    Socialtext::Rest::TaggedPages
    Socialtext::Rest::Tags
    Socialtext::Rest::User
    Socialtext::Rest::UserSharedAccounts
    Socialtext::Rest::Users
    Socialtext::Rest::Version
    Socialtext::Rest::WSDL
    Socialtext::Rest::Wafl
    Socialtext::Rest::Workspace
    Socialtext::Rest::WorkspaceAttachments
    Socialtext::Rest::WorkspaceTags
    Socialtext::Rest::WorkspaceUser
    Socialtext::Rest::WorkspaceUsers
    Socialtext::Rest::Workspaces
    Socialtext::RevisionPlugin
    Socialtext::RtfExportPlugin
    Socialtext::SOAPGoogle
    Socialtext::SOAPPlugin
    Socialtext::SOAPServer
    Socialtext::Search
    Socialtext::Search::Basic::Factory
    Socialtext::Search::Basic::Indexer
    Socialtext::Search::Basic::Searcher
    Socialtext::Search::Config
    Socialtext::Search::ContentTypes
    Socialtext::Search::KinoSearch::Analyzer
    Socialtext::Search::KinoSearch::Analyzer::Base
    Socialtext::Search::KinoSearch::Analyzer::Ja::Tokenize
    Socialtext::Search::KinoSearch::Analyzer::Ja::mecabif
    Socialtext::Search::KinoSearch::Analyzer::LowerCase
    Socialtext::Search::KinoSearch::Analyzer::Stem
    Socialtext::Search::KinoSearch::Analyzer::Tokenize
    Socialtext::Search::KinoSearch::Factory
    Socialtext::Search::KinoSearch::Indexer
    Socialtext::Search::KinoSearch::QueryParser
    Socialtext::Search::KinoSearch::Searcher
    Socialtext::Search::Set
    Socialtext::Search::Utils
    Socialtext::SearchPlugin
    Socialtext::ShortcutLinksPlugin
    Socialtext::Skin
    Socialtext::Statistic
    Socialtext::Statistic::HeapDelta
    Socialtext::Statistics
    Socialtext::Stax
    Socialtext::Storage
    Socialtext::Syndicate::Atom
    Socialtext::Syndicate::RSS20
    Socialtext::SyndicatePlugin
    Socialtext::System
    Socialtext::SystemSettings
    Socialtext::Template
    Socialtext::Template::Plugin::decorate
    Socialtext::Template::Plugin::encode_mailto
    Socialtext::Template::Plugin::fillinform
    Socialtext::Template::Plugin::flatten
    Socialtext::Template::Plugin::html_encode
    Socialtext::Template::Plugin::label_ellipsis
    Socialtext::TheSchwartz
    Socialtext::TiddlyPlugin
    Socialtext::TimeZonePlugin
    Socialtext::Timer
    Socialtext::UniqueArray
    Socialtext::UploadedImage
    Socialtext::User
    Socialtext::User::Cache
    Socialtext::User::EmailConfirmation
    Socialtext::User::Find
    Socialtext::User::Find::Workspace
    Socialtext::UserPreferencesPlugin
    Socialtext::UserSettingsPlugin
    Socialtext::Validate
    Socialtext::WatchlistPlugin
    Socialtext::WebApp
    Socialtext::WeblogArchive
    Socialtext::WeblogPlugin
    Socialtext::WikiFixture::ApplianceConfig
    Socialtext::WikiFixture::EmailJob
    Socialtext::WikiFixture::SocialBase
    Socialtext::WikiFixture::SocialpointPlugin
    Socialtext::WikiText::Emitter::HTML
    Socialtext::WikiText::Emitter::Messages::Base
    Socialtext::WikiText::Emitter::Messages::Canonicalize
    Socialtext::WikiText::Emitter::Messages::HTML
    Socialtext::WikiText::Emitter::SearchSnippets
    Socialtext::WikiText::Parser
    Socialtext::WikiText::Parser::Messages
    Socialtext::Wikil10n
    Socialtext::Wikiwyg::AnalyzerPlugin
    Socialtext::WikiwygPlugin
    Socialtext::Workspace::Importer
    Socialtext::Workspace::Permissions
    Socialtext::WorkspaceBreadcrumb
    Socialtext::WorkspaceInvitation
    Socialtext::WorkspaceListPlugin
    Socialtext::WorkspacesUIPlugin
    Test::HTTP::Socialtext
    Test::Live
    Test::SeleniumRC
    Test::Socialtext
    Test::Socialtext::Account
    Test::Socialtext::CGIOutput
    Test::Socialtext::Ceqlotron
    Test::Socialtext::Environment
    Test::Socialtext::Fixture
    Test::Socialtext::Mechanize
    Test::Socialtext::Search
    Test::Socialtext::Thrower
);

###############################################################################
# List of modules that have exceptions, where we know that certain methods may
# not require POD (for one reason or another).
my %ModuleExceptions = (
    'Socialtext::Account'       => { trustme => [qr/DefaultOrderByColumn/] },
    'Socialtext::MooseX::SQL'   => { trustme => ['init_meta'] },
    'Socialtext::User::Default' => { trustme => [qr/DefaultOrderByColumn/] },
    'Socialtext::Workspace'     => { trustme => [qr/DefaultOrderByColumn/] },
    'Socialtext::URI'           => { trustme => [qr/^uri(?:_object)?$/] },
    'Socialtext::Search::SimplePageHit' =>
        { trustme => [qr/^page_uri|workspace_name|key$/] },
    'Socialtext::Search::SimpleAttachmentHit' =>
        { trustme => [qr/^page_uri|attachment_id|workspace_name|key$/] },
);


###############################################################################
# Find all the modules, and plan our tests
my @all_modules = @ARGV;
unless (@all_modules) {
    @all_modules = all_core_modules();
}
plan tests => scalar @all_modules;

###############################################################################
# Test each module in turn
foreach my $file (sort @all_modules) {
    my $module  = file_to_module($file);
    my $is_todo = exists $ToDoModules{$module};
    my $params  = $ModuleExceptions{$module} || {};
    TODO: {
        local $TODO = 'old module' if ($is_todo);
        pod_coverage_ok( $module, $params );
    }
}
exit;


###############################################################################
# Find all modules in "lib/" that are *files* (e.g. they haven't been
# symlinked in from some other part of the system).
sub all_core_modules {
    my @all_files = `find lib -type f -name "*.pm"`;
    chomp @all_files;
    return @all_files;
}

###############################################################################
# Takes a filename (e.g. "lib/Socialtext/Apache/AuthenHandler.pm") and
# converts that into a module name (e.g. "Socialtext::Apache::AuthenHandler").
sub file_to_module {
    my $file = shift;
    $file =~ s{lib/}{};             # strip leading "lib/"
    $file =~ s{\.pm$}{};            # strip file suffix
    $file =~ s{/}{::}g;             # convert file to module name
    return $file;
}
