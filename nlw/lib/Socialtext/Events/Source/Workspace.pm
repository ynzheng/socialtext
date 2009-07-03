package Socialtext::Events::Source::Workspace;
use Moose;
use Socialtext::SQL::Builder qw/sql_abstract/;
use Socialtext::Events::Event::Page;
use namespace::clean -except => 'meta';

with 'Socialtext::Events::Source', 'Socialtext::Events::SQLSource';

has 'workspace_id' => ( is => 'ro', isa => 'Int', required => 1 );

sub next { 
    Socialtext::Events::Event::Page->new($_[0]->next_sql_result);
}

sub query_and_binds {
    my $self = shift;

    $self->filter->clear_page_workspace_id;

    my @where = (
        \"event_class = 'page'",
        ($self->filter->contributions ? \"is_page_contribution(action)" : ()),
        'page_workspace_id' => $self->workspace_id,
    );

    $self->add_where_clauses(\@where);

    if ($self->filter->followed) {
        push @where, actor_id => [
            \q{IN (SELECT person_id2
                   FROM person_watched_people__person
                   WHERE person_id1=?)},
            $self->viewer_id
        ];
    }

    my $sa = sql_abstract();
    my ($sql, @binds) = $sa->select(
        'event', $self->columns, \@where, 'at DESC', $self->limit
    );
    return $sql, \@binds;
}

sub add_where_clauses {
    my $self = shift;
    my $where = shift;
    push @$where, -nest => $self->filter->generate_standard_filter();
}

around 'columns' => sub {
    return shift->().', page_id, page_workspace_id';
};

__PACKAGE__->meta->make_immutable;
1;

# package Socialtext::Events::Source::Workspace::Conversations;
# use Moose;
# 
# extends 'Socialtext::Events::Source::Workspace';
# 
# before 'query_and_binds' => sub {
#     my $self = shift;
#     $self->filter->contributions(1);
# };
# 
# my $my_convos = q{
#     -- it's in my watchlist
#     EXISTS (
#         SELECT 1
#         FROM "Watchlist" wl
#         WHERE page_workspace_id = wl.workspace_id
#           AND wl.user_id = ?
#           AND page_id = wl.page_text_id::text
#     )
#     OR
#     -- i created it
#     EXISTS (
#         SELECT 1
#         FROM page p
#         WHERE p.workspace_id = event.page_workspace_id
#           AND p.page_id = event.page_id
#           AND p.creator_id = ?
#     )
#     OR
#     -- they contributed to it after i did
#     EXISTS (
#         SELECT 1
#         FROM event my_contribs
#         WHERE my_contribs.event_class = 'page'
#           AND is_page_contribution(my_contribs.action)
#           AND my_contribs.actor_id = ?
#           AND my_contribs.page_workspace_id = event.page_workspace_id
#           AND my_contribs.page_id = event.page_id
#           AND my_contribs.at < event.at
#     )
# };
# 
# override 'add_where_clauses' => sub {
#     my $self = shift;
#     my $where = shift;
# 
#     push @$where, -nest => [\$my_convos, ($self->viewer_id) x 3];
# 
#     push @$where, -nest => $self->filter->generate_filter(
#         qw(before after action actor_id page_id tag_name));
# };
# 
# __PACKAGE__->meta->make_immutable;
# 1;
