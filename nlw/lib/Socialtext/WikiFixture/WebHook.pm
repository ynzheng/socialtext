package Socialtext::WikiFixture::WebHook;
# @COPYRIGHT@
use Socialtext::AppConfig;
use Socialtext::System qw/shell_run/;
use Socialtext::File qw/get_contents_utf8/;
use Test::More;
use Moose;

extends 'Socialtext::WikiFixture::SocialRest';

after 'init' => sub {
    shell_run('nlwctl -c stop');
};

sub webhook_file { Socialtext::AppConfig->data_root_dir . '/webhooks.txt' }

sub clear_webhook {
    my $self = shift;
    unlink $self->webhook_file;
}

sub _get_webhook_contents {
    my $self = shift;
    my $contents = '__NO CONTENT!__';
    if (-f $self->webhook_file) {
        $contents = get_contents_utf8($self->webhook_file);
    }
    return $contents;
}

sub webhook_like {
    my $self = shift;
    my $expected = shift;

    my $contents = $self->_get_webhook_contents;
    like $contents, qr/$expected/, 'webhook contents';
}

sub webhook_unlike {
    my $self = shift;
    my $expected = shift;

    my $contents = $self->_get_webhook_contents;
    unlike $contents, qr/$expected/, 'webhook contents';
}


around 'st_process_jobs' => sub {
    my $orig = shift;
    my $self = shift;

    local $ENV{ST_WEBHOOK_TO_FILE} = $self->webhook_file;
    return $self->$orig(@_);
};

1;
