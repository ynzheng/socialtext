#!perl
use warnings;
use strict;

use Test::More tests => 999;
use Data::Dumper;

use mocked 'Apache::Cookie';
use mocked 'Socialtext::Search::Config';
use mocked 'Socialtext::Account';
use mocked 'Socialtext::Workspace';
use mocked 'Socialtext::User';
use mocked 'Socialtext::CGI';
use mocked 'Socialtext::Hub';
use Socialtext::Plugin;

use_ok 'Socialtext::CategoryPlugin';

my $user = Socialtext::User->new(email_address => 'test@ken.socialtext.net');
my $ws = Socialtext::Workspace->new(name => 'testws');
my $hub = Socialtext::Hub->new(current_workspace => $ws, current_user => $user);

my @added_tags;
{
    no warnings 'once', 'redefine';
    *Socialtext::Workspace::email_address = sub { 'category-addr@example.com'};
    *Socialtext::Workspace::email_weblog_dot_address = sub { 'category-addr@example.com'};

    *Socialtext::Plugin::template_process = sub { 'rendered' };

    *Socialtext::Page::add_tags = sub {
        my $page = shift;
        push @added_tags, [$page->id, @_];
    };
}

none_selected: {
    my $cgi = Socialtext::Category::CGI->new(
        category => 'cats',
    );
    my $cat_plug = Socialtext::CategoryPlugin->new(hub => $hub, cgi => $cgi);
    ok $cat_plug;
    $cat_plug->tag_many_pages;
    is_deeply \@added_tags, [], 'no tags added';
    @added_tags = ();
}

some_selected: {
    my $cgi = Socialtext::Category::CGI->new(
        category => ['dogs'],
        page_selected => ['a','b','c'],
    );

    my $cat_plug = Socialtext::CategoryPlugin->new(hub => $hub, cgi => $cgi);
    ok $cat_plug;
    $cat_plug->tag_many_pages;
    is_deeply \@added_tags, [['a','dogs'],['b','dogs'],['c','dogs']],
        "three pages tagged";
    @added_tags = ();
}

many_pages_many_tags: {
    my $cgi = Socialtext::Category::CGI->new(
        category => ['bird', 'parrot'],
        page_selected => ['d','e'],
    );
    my $cat_plug = Socialtext::CategoryPlugin->new(hub => $hub, cgi => $cgi);
    ok $cat_plug;
    $cat_plug->tag_many_pages;
    is_deeply \@added_tags, [
        ['d','bird','parrot'],
        ['e','bird','parrot'],
    ], "pages tagged";
    @added_tags = ();
}

1;
