package Socialtext::Events::Source::Workspace;
use Moose;
use Socialtext::SQL::Builder qw/sql_abstract/;
use Socialtext::Events::Event::Page;
use namespace::clean -except => 'meta';

with 'Socialtext::Events::Source', 'Socialtext::Events::SQLSource';

has 'workspace_id' => ( is => 'ro', isa => 'Int', required => 1 );

sub next { 
    my $self = shift;
    my $e = Socialtext::Events::Event::Page->new($self->next_sql_result);
    $e->source($self);
    return $e;
}

sub query_and_binds {
    my $self = shift;

    $self->filter->clear_page_workspace_id;

    my @where = (
        \"event_class = 'page'",
        ($self->filter->contributions ? \"is_page_contribution(action)" : ()),
        'page_workspace_id' => $self->workspace_id,
    );

    push @where, -nest => $self->filter->generate_standard_filter();

    if ($self->filter->followed) {
        push @where, actor_id => \[$self->followed_clause, $self->viewer_id];
    }

    my $sa = sql_abstract();
    my ($sql, @binds) = $sa->select(
        'event', $self->columns, \@where, 'at DESC', $self->limit
    );
    return $sql, \@binds;
}

around 'columns' => sub {
    return shift->().', page_id, page_workspace_id';
};

__PACKAGE__->meta->make_immutable;
1;

