package Socialtext::Events::Reporter;
# @COPYRIGHT@
use Moose;

use Socialtext::Encode ();
use Socialtext::SQL qw/sql_execute/;
use Socialtext::JSON qw/decode_json/;
use Socialtext::User;
use Socialtext::Pluggable::Adapter;
use Socialtext::Timer qw/time_this/;
use Class::Field qw/field/;
use Socialtext::WikiText::Parser::Messages;
use Socialtext::WikiText::Emitter::Messages::HTML;

use Socialtext::Events::FilterParams;
use Socialtext::Events::Stream;
use Socialtext::Events::Stream::HasPages;
use Socialtext::Events::Stream::HasPeople;
use Socialtext::Events::Stream::HasSignals;
use Socialtext::Events::Stream::Pages;
use Socialtext::Events::Stream::Regular;
use Socialtext::Events::Stream::ProfileActivity;
use Socialtext::Events::Stream::Conversations;

has 'viewer' => (is => 'ro', isa => 'Socialtext::User',
    handles => {
        viewer_id => 'user_id'
    }
);

sub get_events {
    my $self   = shift;
    my $opts = ref($_[0]) eq 'HASH' ? $_[0] : {@_};

    my $evc = delete $opts->{event_class};
    if ($evc && !(ref $evc) && $evc eq 'page' && $opts->{contributions})
    {
        return $self->get_events_page_contribs($opts);
    }

    my %opts_slice = map { $_ => $opts->{$_} }
        grep { exists $opts->{$_} }
        qw(action before after page_id page_workspace_id actor_id person_id followed tag_name);

    my $limit = $opts->{limit} || $opts->{count} || 50;
    my $offset = $opts->{offset} || 0;
    
    my %construct = (
        viewer => $self->viewer,
        user => $self->viewer,
        limit => $limit,
        offset => $offset,
        filter => Socialtext::Events::FilterParams->new(
            %opts_slice,
        )
    );
    
    my $result = [];
    time_this {
        my $stream;

        if (!$evc) {
            $stream = Socialtext::Events::Stream::Regular->new(
                %construct
            );
        }
        else {
            # These are prefixed with 'Socialtext::Events::Stream'
            my %trait_map = (
                page => 'HasPages',
                person => 'HasPeople',
                signal => 'HasSignals',
            );
            my @traits = map { $trait_map{$_} ? $trait_map{$_} : () }
                @{ref($evc) ? $evc : [$evc]};

            if (!@traits) {
                warn 'all event class parameters are unsupported';
            }
            else {
                $stream = Socialtext::Events::Stream->new_with_traits(
                    %construct,
                    traits => \@traits,
                );
            }
        }
        if ($stream) {
            $stream->prepare();
            $result = $stream->all_hashes();
        }
    } 'get_events';

    return @$result if wantarray;
    return $result;
}

sub get_events_page_contribs {
    my $self = shift;
    my $opts = ref($_[0]) eq 'HASH' ? $_[0] : {@_};

    my %opts_slice = map { $_ => $opts->{$_} }
        grep { exists $opts->{$_} }
        qw(actor_id before after followed tag_name);

    my $limit = $opts->{limit} || $opts->{count} || 50;
    my $offset = $opts->{offset} || 0;

    my $result = [];
    time_this {
        my $stream = Socialtext::Events::Stream::Pages->new(
            viewer => $self->viewer,
            limit => $limit,
            offset => $offset,
            filter => Socialtext::Events::FilterParams->new(
                contributions => 1,
                %opts_slice,
            ),
        );

        $stream->prepare();
        $result = $stream->all_hashes();
    } 'get_page_contribs';

    return @$result if wantarray;
    return $result;
}

sub get_events_activities {
    my $self = shift;
    my $maybe_user = shift;
    my $opts = ref($_[0]) eq 'HASH' ? $_[0] : {@_};

    # First we need to get the user id in case this was email or username used
    my $user = Socialtext::User->Resolve($maybe_user);
    return [] unless $user;

    my %opts_slice = map { $_ => $opts->{$_} }
        grep { exists $opts->{$_} }
        qw(before after page_id page_workspace_id actor_id person_id tag_name);
    my $limit = $opts->{limit} || $opts->{count} || 50;
    my $offset = $opts->{offset} || 0;

    my $result = [];
    time_this {
    eval {
        my $stream = Socialtext::Events::Stream::ProfileActivity->new(
            filter => Socialtext::Events::FilterParams->new(
                %opts_slice,
            ),
            user => $user,
            viewer => $self->viewer,
            limit => $limit,
            offset => $offset,
        );

        $stream->prepare();
        $result = $stream->all_hashes();
    }; warn $@ if $@; die $@ if $@;
    } 'get_activity';

    return @$result if wantarray;
    return $result;
}

sub get_events_conversations {
    my $self = shift;
    my $maybe_user = shift;
    my $opts = (@_==1) ? $_[0] : {@_};

    # filter the options to a subset of what's usually allowed
    my %opts_slice = map {
        defined($opts->{$_}) ? ($_ => $opts->{$_}) : ()
    } qw(
       action actor_id page_workspace_id page_id tag_name
       before after
    );
    my $limit = $opts->{limit} || $opts->{count} || 50;
    my $offset = $opts->{offset} || 0;
    delete $opts_slice{actor_id} unless defined $opts_slice{actor_id};

    # First we need to get the user id in case this was email or username used
    my $user = Socialtext::User->Resolve($maybe_user);
    return [] unless $user;

    my $result = [];
    time_this {
    eval {
        my $stream = Socialtext::Events::Stream::Conversations->new(
            filter => Socialtext::Events::FilterParams->new(
                %opts_slice,
            ),
            user => $user,
            viewer => $self->viewer,
            limit => $limit,
            offset => $offset,
        );

        $stream->prepare();
        $result = $stream->all_hashes();
    }; warn $@ if $@; die $@ if $@;
    } 'get_convos';

    return @$result if wantarray;
    return $result;
}

sub get_events_followed {
    my $self = shift;
    my $opts = (@_ == 1) ? $_[0] : {@_};

    $opts->{followed} = 1;
    $opts->{contributions} = 1;
    $opts->{"action!"} = 'view';
    die "no limit?!" unless $opts->{count};
    my $result;
    time_this { $result = $self->get_events($opts) } 'get_followed_events';
    return @$result if wantarray;
    return $result;
}

sub get_page_contention_events {
    my $self = shift;
    my $opts = (@_==1) ? shift : {@_};
    
    local $self->{_skip_standard_opts} = 1;
    local $self->{_skip_visibility} = 1;
    $opts->{event_class} = 'page';
    $opts->{action} = [qw(edit_start edit_cancel)];
    my ($sql, $args) = $self->_build_standard_sql($opts);

    Socialtext::Timer->Continue('get_page_contention_events');
    #$Socialtext::SQL::PROFILE_SQL = 1;
    my $sth = sql_execute($sql, @$args);
    #$Socialtext::SQL::PROFILE_SQL = 0;
    Socialtext::Timer->Pause('get_page_contention_events');
    my $result = $self->decorate_event_set($sth);
    return $result;
}

1;
