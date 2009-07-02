package Socialtext::Events::Event;
use Moose;
use MooseX::StrictConstructor;
use namespace::clean -except => 'meta';

has 'at_epoch' => ( is => 'ro', isa => 'Num', required => 1 );
has 'at' => ( is => 'ro', isa => 'Str', required => 1 );

has 'actor_id' => (is => 'ro', isa => 'Int', required => 1 );
has 'action' => (is => 'ro', isa => 'Str', required => 1 );
has 'context' => (is => 'ro', isa => 'HashRef');

__PACKAGE__->meta->make_immutable;

package Socialtext::Events::Event::Page;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use namespace::clean -except => 'meta';

extends 'Socialtext::Events::Event';

enum 'PageEventAction' => qw(
    comment
    delete
    duplicate
    edit_cancel
    edit_contention
    edit_save
    edit_start
    lock_page
    rename
    tag_add
    tag_delete
    unlock_page
    view
    watch_add
    watch_delete
);

has '+action' => (isa => 'PageEventAction');

__PACKAGE__->meta->make_immutable;
1;
