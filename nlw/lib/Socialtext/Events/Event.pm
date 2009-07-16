package Socialtext::Events::Event;
use Moose;
use MooseX::StrictConstructor;
use Carp qw/croak/;
use DateTime;
use Socialtext::User;
use Socialtext::JSON qw/decode_json/;
use Socialtext::Encode;
use namespace::clean -except => 'meta';

has 'source' => (
    is => 'rw', isa => 'Socialtext::Events::Source', 
    predicate => 'has_source',
);

has 'at_epoch' => (is => 'ro', isa => 'Num', required => 1);
has 'at'       => (is => 'ro', isa => 'Str', required => 1);
has 'at_dt'    => (is => 'ro', isa => 'DateTime', lazy_build => 1);

has 'action'   => (is => 'ro', isa => 'Str', required => 1);
has 'tag_name' => (is => 'ro', isa => 'Maybe[Str]');

has 'context'  => (is => 'ro', isa => 'Maybe[Str]');
has 'context_hash' => (is => 'ro', isa => 'HashRef', lazy_build => 1);

has 'actor_id' => (is => 'ro', isa => 'Int', required => 1);
has 'actor'    => (is => 'ro', isa => 'Socialtext::User', lazy_build => 1);

sub _build_at_dt { DateTime->from_epoch(epoch => $_[0]->at_epoch) }

sub _build_context_hash {
    my $self = shift;
    my $c = $self->context;
    return {} if !$c;
    eval {
        $c = Encode::encode_utf8(Socialtext::Encode::ensure_is_utf8($c));
        $c = decode_json($c);
    };
    warn "unable to decode json: $@" if $@;
    return $c;
}

sub _build_actor { Socialtext::User->new(user_id => $_[0]->actor_id) }

sub add_user_to_hash {
    my $self = shift;
    my $field = shift;
    my $user = shift;
    my $hash = shift;

    my $id = $user->user_id;
    my $avatar_is_visible = $user->avatar_is_visible || 0;
    my $profile_is_visible = $user->profile_is_visible_to($self->source->viewer) || 0;
    my $hidden = 1;

    # TODO: ick. this belongs in the plugins as hook to decorate event hashes
    require Socialtext::Pluggable::Adapter;
    my $adapter = Socialtext::Pluggable::Adapter->new;
    if ($adapter->plugin_exists('people')) {
        require Socialtext::People::Profile;
        my $profile = Socialtext::People::Profile->GetProfile($user);
        $hidden = $profile->is_hidden if $profile;
    }

    my $uh = $hash->{$field};
    $uh->{id}                 = $id;
    $uh->{best_full_name}     = $user->guess_real_name();
    $uh->{uri}                = "/data/people/$id";
    $uh->{hidden}             = $hidden;
    $uh->{avatar_is_visible}  = $avatar_is_visible;
    $uh->{profile_is_visible} = $profile_is_visible;
}

# roles/extending classes should hook this with an 'after' sub
sub build_hash {
    my $self = shift;
    my $hash = shift
        or croak 'build_hash requires an empty hash parameter';

    $hash->{at} = $self->at;

    $hash->{actor} ||= {};
    $self->add_user_to_hash('actor' => $self->actor, $hash);

    $hash->{tag_name} = $self->tag_name if defined $self->tag_name;
    $hash->{action} = $self->action;

    $hash->{context} = $self->context_hash; # TODO: thunk this

    return $hash;
}

__PACKAGE__->meta->make_immutable;
1;
