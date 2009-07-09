package Socialtext::Events::Event::Signal;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
# ugh... mixing view with the model :(
use Socialtext::WikiText::Parser::Messages;
use Socialtext::WikiText::Emitter::Messages::HTML;
use namespace::clean -except => 'meta';

extends 'Socialtext::Events::Event';
with 'Socialtext::Events::Event::HasPerson';

enum 'SignalEventAction' => qw(
    page_edit
    signal
);

has 'signal_id' => (is => 'ro', isa => 'Int', required => 1);
# purposefully no signal attr for now; Signal plugin needs to build it.

has '+person_id' => (isa => 'Maybe[Int]');

has 'html_body' => (is => 'ro', isa => 'Str', lazy_build => 1);

sub is_direct_signal {
    my $self = shift;
    return defined $self->person_id
}

sub _build_html_body {
    my $self = shift;
    my $ctx = $self->context_hash;
    die "no context hash" unless $ctx;
    my $parser = Socialtext::WikiText::Parser::Messages->new(
       receiver => Socialtext::WikiText::Emitter::Messages::HTML->new(
           callbacks => {
               viewer => $self->source->viewer,
           },
       )
    );
    return $parser->parse($ctx->{body});
}

after 'build_hash' => sub {
    my $self = shift;
    my $hash = shift;

    $hash->{event_class} = 'signal';

    # TODO: thunk this or allow plugins to hook "build_hash"
    $hash->{context}{body} = $self->html_body;
};

__PACKAGE__->meta->make_immutable;
1;
