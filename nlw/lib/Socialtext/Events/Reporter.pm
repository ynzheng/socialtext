package Socialtext::Events::Reporter;
# @COPYRIGHT@
use warnings;
use strict;
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

field 'viewer';

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    return bless {
        @_,
        _conditions => [],
        _condition_args => [],
        _outer_conditions => [],
        _outer_condition_args => [],
    }, $class;
}

sub add_condition {
    my $self = shift;
    my $cond = shift;
    push @{$self->{_conditions}}, $cond;
    push @{$self->{_condition_args}}, @_;
}

sub prepend_condition {
    my $self = shift;
    my $cond = shift;
    unshift @{$self->{_conditions}}, $cond;
    unshift @{$self->{_condition_args}}, @_;
}

sub add_outer_condition {
    my $self = shift;
    my $cond = shift;
    push @{$self->{_outer_conditions}}, $cond;
    push @{$self->{_outer_condition_args}}, @_;
}

sub prepend_outer_condition {
    my $self = shift;
    my $cond = shift;
    unshift @{$self->{_outer_conditions}}, $cond;
    unshift @{$self->{_outer_condition_args}}, @_;
}

our @QueryOrder = qw(
    event_class
    action
    actor_id
    person_id
    page_workspace_id
    page_id
    tag_name
);

sub _best_full_name {
    my $p = shift;

    my $full_name;
    if ($p->{first_name} || $p->{last_name}) {
        $full_name = "$p->{first_name} $p->{last_name}";
    }
    elsif ($p->{email}) {
        ($full_name = $p->{email}) =~ s/@.*$//;
    }
    elsif ($p->{name}) {
        ($full_name = $p->{name}) =~ s/@.*$//;
    }
    return $full_name;
}

sub _extract_person {
    my ($self, $row, $prefix) = @_;
    my $id = delete $row->{"${prefix}_id"};
    return unless $id;

    # this real-name calculation may benefit from caching at some point
    my $real_name;
    my $user = Socialtext::User->new(user_id => $id);
    my $avatar_is_visible = $user->avatar_is_visible || 0;
    if ($user) {
        $real_name = $user->guess_real_name();
    }

    my $profile_is_visible = $user->profile_is_visible_to($self->viewer) || 0;
    my $hidden = 1;
    my $adapter = Socialtext::Pluggable::Adapter->new;
    if ($adapter->plugin_exists('people')) {
        require Socialtext::People::Profile;
        my $profile = Socialtext::People::Profile->GetProfile($user);
        $hidden = $profile->is_hidden if $profile;
    }

    $row->{$prefix} = {
        id => $id,
        best_full_name => $real_name,
        uri => "/data/people/$id",
        hidden => $hidden,
        avatar_is_visible => $avatar_is_visible,
        profile_is_visible => $profile_is_visible,
    };
}

sub _extract_page {
    my $self = shift;
    my $row = shift;

    my $page = {
        id => delete $row->{page_id} || undef,
        name => delete $row->{page_name} || undef,
        type => delete $row->{page_type} || undef,
        workspace_name => delete $row->{page_workspace_name} || undef,
        workspace_title => delete $row->{page_workspace_title} || undef,
    };

    if ($page->{workspace_name} && $page->{id}) {
        $page->{uri} =
            "/data/workspaces/$page->{workspace_name}/pages/$page->{id}";
    }

    $row->{page} = $page if ($row->{event_class} eq 'page');
}

sub _expand_context {
    my $self = shift;
    my $row = shift;
    my $c = $row->{context};
    if ($c) {
        local $@;
        $c = Encode::encode_utf8(Socialtext::Encode::ensure_is_utf8($c));
        $c = eval { decode_json($c) };
        warn $@ if $@;
    }
    $c = defined($c) ? $c : {};
    $row->{context} = $c;
}

sub _extract_signal {
    my $self = shift;
    my $row = shift;
    return unless $row->{event_class} eq 'signal';
    my $parser = Socialtext::WikiText::Parser::Messages->new(
       receiver => Socialtext::WikiText::Emitter::Messages::HTML->new(
           callbacks => {
               viewer => $self->viewer,
           },
       )
    );
    $row->{context}{body} = $parser->parse($row->{context}{body});
}

sub decorate_event_set {
    my $self = shift;
    my $sth = shift;

    my $result = [];

    while (my $row = $sth->fetchrow_hashref) {
        $self->_extract_person($row, 'actor');
        $self->_extract_person($row, 'person');
        $self->_extract_page($row);
        $self->_expand_context($row);
        $self->_extract_signal($row);

        delete $row->{person}
            if (!defined($row->{person}) and $row->{event_class} ne 'person');

        $row->{at} = delete $row->{at_utc};

        push @$result, $row;
    }

    return $result;
}

my $FIELDS = <<'EOSQL';
    at AT TIME ZONE 'UTC' || 'Z' AS at_utc,
    at AS at,
    event_class AS event_class,
    action AS action,
    actor_id AS actor_id,
    person_id AS person_id,
    page.page_id as page_id,
        page.name AS page_name,
        page.page_type AS page_type,
    w.name AS page_workspace_name,
        w.title AS page_workspace_title,
    tag_name AS tag_name,
    context AS context
EOSQL

my $SIGNAL_VIS_SQL = <<'EOSQL';
    AND account_id IN (
        SELECT account_id
        FROM signal_account sa
        WHERE sa.signal_id = evt.signal_id
    )
    AND (
        evt.person_id IS NULL
        OR evt.person_id = ?
        OR evt.actor_id = ?
    )
EOSQL

sub visible_exists {
    my ($plugin, $event_field) = @_;
    my $sql = <<EOSQL;
       EXISTS (
            SELECT 1
            FROM account_user viewer
            JOIN account_plugin USING (account_id)
            JOIN account_user othr USING (account_id)
            WHERE plugin = '$plugin' AND viewer.user_id = ?
              AND othr.user_id = $event_field
              -- signal vis
        )
EOSQL

    if ($plugin eq 'signals') {
        $sql =~ s/-- signal vis/$SIGNAL_VIS_SQL/;
    }
    return $sql;
}

my $VISIBILITY_SQL = join "\n",
    '(',
        "(evt.event_class <> 'person' OR (",
            visible_exists('people', 'evt.actor_id'),
            "AND",
            visible_exists('people', 'evt.person_id'),
        '))',
        "AND ( evt.event_class <> 'signal' OR",
            visible_exists('signals', 'evt.actor_id'),
        ')',
    ')';

my $VISIBLE_WORKSPACES = <<'EOSQL';
    SELECT workspace_id FROM "UserWorkspaceRole" WHERE user_id = ?
    UNION ALL
    SELECT workspace_id
    FROM "WorkspaceRolePermission" wrp
    JOIN "Role" r USING (role_id)
    JOIN "Permission" p USING (permission_id)
    WHERE
        -- workspace vis
        r.name = 'guest' AND p.name = 'read'
EOSQL

my $I_CAN_USE_THIS_WORKSPACE = <<"EOSQL";
    page_workspace_id IS NULL OR
    page_workspace_id IN ( $VISIBLE_WORKSPACES )
EOSQL

my $FOLLOWED_PEOPLE_ONLY = <<'EOSQL';
(
   (actor_id IN (
        SELECT person_id2
        FROM person_watched_people__person
        WHERE person_id1=?))
   OR
   (person_id IN (
        SELECT person_id2
        FROM person_watched_people__person
        WHERE person_id1=?))
)
EOSQL

my $CONTRIBUTIONS = <<'EOSQL';
    (event_class = 'person' AND is_profile_contribution(action))
    OR
    (event_class = 'page' AND is_page_contribution(action))
    OR
    (event_class = 'signal')
EOSQL

sub _process_before_after {
    my $self = shift;
    my $opts = shift;
    if (my $b = $opts->{before}) {
        $self->add_condition('at < ?::timestamptz', $b);
    }
    if (my $a = $opts->{after}) {
        $self->add_condition('at > ?::timestamptz', $a);
    }
}

sub _process_field_conditions {
    my $self = shift;
    my $opts = shift;

    foreach my $eq_key (@QueryOrder) {
        next unless exists $opts->{$eq_key};

        my $arg = $opts->{$eq_key};
        if ((defined $arg) && (ref($arg) eq "ARRAY")) {
            my $placeholders = "(".join(",", map( "?", @$arg)).")";
            $self->add_condition("e.$eq_key IN $placeholders", @$arg);
        }
        elsif (defined $arg) {
            $self->add_condition("e.$eq_key = ?", $arg);
        }
        else {
            $self->add_condition("e.$eq_key IS NULL");
        }
    }
}

sub _limit_and_offset {
    my $self = shift;
    my $opts = shift;

    my @args;

    my $limit = '';
    if (my $l = $opts->{limit} || $opts->{count}) {
        $limit = 'LIMIT ?';
        push @args, $l;
    }
    my $offset = '';
    if (my $o = $opts->{offset}) {
        $offset = 'OFFSET ?';
        push @args, $o;
    }

    my $statement = join(' ',$limit,$offset);
    return ($statement, @args);
}

sub _build_standard_sql {
    my $self = shift;
    my $opts = shift;

    $self->_process_before_after($opts);

    unless ($self->{_skip_standard_opts}) {
        $self->prepend_condition(
            $I_CAN_USE_THIS_WORKSPACE => $self->viewer->user_id
        );

        unless ($self->{_skip_visibility}) {
            $self->add_outer_condition(
                $VISIBILITY_SQL => ($self->viewer->user_id) x 5
            );
        }

        if ($opts->{followed}) {
            $self->add_condition(
                $FOLLOWED_PEOPLE_ONLY => ($self->viewer->user_id) x 2
            );
        }

        # filter for contributions-type events
        $self->add_condition($CONTRIBUTIONS)
            if $opts->{contributions};
    }

    $self->_process_field_conditions($opts);

    my ($limit_stmt, @limit_args) = $self->_limit_and_offset($opts);

    my $where = join("\n  AND ",
                     map {"($_)"} ('1=1',@{$self->{_conditions}}));
    my $outer_where = join("\n  AND ",
                           map {"($_)"} ('1=1',@{$self->{_outer_conditions}}));

    my $sql = <<EOSQL;
SELECT $FIELDS FROM (
    SELECT evt.* FROM (
        SELECT e.*
        FROM event e
        WHERE $where
        ORDER BY at DESC
    ) evt
    WHERE
    $outer_where
    $limit_stmt
) outer_e
LEFT JOIN page ON (outer_e.page_workspace_id = page.workspace_id AND
                   outer_e.page_id = page.page_id)
LEFT JOIN "Workspace" w ON (outer_e.page_workspace_id = w.workspace_id)

-- the JOINs above mess up the order. Fortunately, the re-sort isn't too hideous after LIMIT-ing
ORDER BY outer_e.at DESC
EOSQL

    return $sql, [@{$self->{_condition_args}}, @{$self->{_outer_condition_args}}, @limit_args];
}

sub _get_events {
    my $self   = shift;
    my $opts = ref($_[0]) eq 'HASH' ? $_[0] : {@_};

    my ($sql, $args) = $self->_build_standard_sql($opts);

    Socialtext::Timer->Continue('get_events');
    #$Socialtext::SQL::PROFILE_SQL = 1;
    my $sth = sql_execute($sql, @$args);
    #$Socialtext::SQL::PROFILE_SQL = 0;
    my $result = $self->decorate_event_set($sth);
    Socialtext::Timer->Pause('get_events');

    return @$result if wantarray;
    return $result;
}

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

    Socialtext::Timer->Continue('get_activity');

    # First we need to get the user id in case this was email or username used
    my $user = Socialtext::User->Resolve($maybe_user);
    my $user_id = $user->user_id;

    my $user_ids;
    my @conditions;
    if (!$opts->{event_class}) {
        $opts->{event_class} = [qw(page person signal)];
    }

    my %classes;
    if (ref $opts->{event_class}) {
        %classes = map {$_ => 1} @{$opts->{event_class}};
    }
    else {
        $classes{$opts->{event_class}} = 1;
    }

    if ($classes{page}) {
        push @conditions, q{
            event_class = 'page'
            AND is_page_contribution(action)
            AND actor_id = ?
        };
        $user_ids++;
    }

    if ($classes{person}) {
        push @conditions, q{
            -- target ix_event_person_contribs_actor
            (event_class = 'person' AND is_profile_contribution(action)
                AND actor_id = ?)
            OR
            -- target ix_event_person_contribs_person
            (event_class = 'person' AND is_profile_contribution(action)
                AND person_id = ?)
        };
        $user_ids += 2;
    }

    if ($classes{signal}) {
        push @conditions, q{
            event_class = 'signal' AND (
                actor_id = ?
                OR EXISTS (
                    SELECT 1
                      FROM topic_signal_user tsu
                     WHERE tsu.signal_id = e.signal_id
                       AND tsu.user_id = ?
                )
                OR person_id = ?
            )
        };
        $user_ids += 3;
    }

    my $cond_sql = join(' OR ', map {"($_)"} @conditions);
    $self->add_condition($cond_sql, ($user_id) x $user_ids);
    my $evs = $self->_get_events(@_);
    Socialtext::Timer->Pause('get_activity');

    return @$evs if wantarray;
    return $evs;
}

my $CONVERSATIONS_WHERE = <<"EOSQL";
  event_class = 'page'
  AND is_page_contribution(action)
  AND e.actor_id <> ?
  AND page_workspace_id IN ( $VISIBLE_WORKSPACES )
  AND (
      -- it's in my watchlist
      EXISTS (
          SELECT 1
          FROM "Watchlist" wl
          WHERE e.page_workspace_id = wl.workspace_id
            AND wl.user_id = ?
            AND e.page_id = wl.page_text_id::text
      )
      OR
      -- i created it
      EXISTS (
          SELECT 1
          FROM page p
          WHERE p.workspace_id = e.page_workspace_id
            AND p.page_id = e.page_id
            AND p.creator_id = ?
      )
      OR
      -- they contributed to it after i did
      EXISTS (
          SELECT 1
          FROM event my_contribs
          WHERE my_contribs.event_class = 'page'
            AND is_page_contribution(my_contribs.action)
            AND my_contribs.actor_id = ?
            AND my_contribs.page_workspace_id
                  = e.page_workspace_id
            AND my_contribs.page_id = e.page_id
            AND my_contribs.at < e.at
      )
  )
EOSQL

sub _build_convos_sql {
    my $self = shift;
    my $opts = shift;

    # filter the options to a subset of what's usually allowed
    my %filtered_opts = map {
        exists($opts->{$_}) ? ($_ => $opts->{$_}) : ()
    } qw(
       action actor_id page_workspace_id page_id tag_name
       before after limit count offset
    );
    delete $filtered_opts{actor_id}
        unless defined $filtered_opts{actor_id};

    local $self->{_skip_standard_opts} = 1;

    my $limit_public_to_contributed = <<EOSQL;
        workspace_id IN
        (
            SELECT page_workspace_id AS workspace_id
            FROM event has_contrib
            WHERE has_contrib.event_class = 'page'
              AND is_page_contribution(has_contrib.action)
              AND has_contrib.actor_id = ?
        ) AND
EOSQL

    (my $conv_where = $CONVERSATIONS_WHERE) =~
        s/-- workspace vis/$limit_public_to_contributed/;
    $self->prepend_condition($conv_where, ($opts->{user_id}) x 6);

    return $self->_build_standard_sql(\%filtered_opts);
}

sub get_events_conversations {
    my $self = shift;
    my $maybe_user = shift;
    my $opts = (@_==1) ? $_[0] : {@_};

    # First we need to get the user id in case this was email or username used
    my $user = Socialtext::User->Resolve($maybe_user);
    my $user_id = $user->user_id;
    $opts->{user_id} = $user_id;

    my ($sql, $args) = $self->_build_convos_sql($opts);

    return [] unless $sql;

    Socialtext::Timer->Continue('get_convos');

    #$Socialtext::SQL::PROFILE_SQL = 1;
    my $sth = sql_execute($sql, @$args);
    #$Socialtext::SQL::PROFILE_SQL = 0;
    my $result = $self->decorate_event_set($sth);

    Socialtext::Timer->Pause('get_convos');

    return @$result if wantarray;
    return $result;
}

sub get_events_followed {
    my $self = shift;
    my $opts = (@_ == 1) ? $_[0] : {@_};

    $opts->{followed} = 1;
    $opts->{contributions} = 1;
    die "no limit?!" unless $opts->{count};

    if ($opts->{action} && $opts->{action} eq 'view') {
        return []; # view events aren't contributions
    }
    else {
        # by using non-view indexes, we can get a simple perf boost until we
        # devise something better
        $self->prepend_condition(q{action <> 'view'});
    }
    my ($followed_sql, $followed_args) = $self->_build_standard_sql($opts);

    Socialtext::Timer->Continue('get_followed_events');
    #$Socialtext::SQL::PROFILE_SQL = 1;
    my $sth = sql_execute($followed_sql, @$followed_args);
    #$Socialtext::SQL::PROFILE_SQL = 0;
    my $result = $self->decorate_event_set($sth);
    Socialtext::Timer->Pause('get_followed_events');
    return $result;
}

sub get_awesome_events {
    my $self = shift;
    my $opts = {@_};

    $opts->{followed} = 1;
    $opts->{contributions} = 1;
    my ($followed_sql, $followed_args) = $self->_build_standard_sql($opts);

    delete $opts->{followed};
    delete $opts->{contributions};
    $opts->{user_id} = $self->viewer->user_id;
    my ($convos_sql, $convos_args) = $self->_build_convos_sql($opts);
    if (!$convos_sql) {
        return $self->get_events(%$opts);
    }

    my ($limit_stmt, @limit_args) = $self->_limit_and_offset($opts);

    my $sql = <<EOSQL;
        SELECT * FROM (
            ($followed_sql)
            UNION
            ($convos_sql)
        ) awesome
        ORDER BY at DESC
        $limit_stmt
EOSQL

    Socialtext::Timer->Continue('get_awesome');

    local $Socialtext::SQL::TRACE_SQL = 1;

    my $sth = sql_execute($sql, @$followed_args, @$convos_args, @limit_args);
    $Socialtext::SQL::TRACE_SQL = 0;
    my $result = $self->decorate_event_set($sth);

    Socialtext::Timer->Pause('get_awesome');

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
