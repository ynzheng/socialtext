package Socialtext::Events::FilterParams;
use Moose;
use Carp qw/croak/;
use MooseX::StrictConstructor;
use namespace::clean -except => 'meta';

use constant AutoFilterParam => 'Socialtext::Events::FilterParams::AutoFilterParam';
{
    package Socialtext::Events::FilterParams::AutoFilterParam;
    use Moose::Role;

    has 'sql_builder' => (
        is => 'ro', isa => 'Str|CodeRef', 
        predicate => 'has_sql_builder',
    );
}

# one thing (defined or not) OR many things (defined)
sub bunch_of {
    my $T = shift;
    return "Maybe[$T]|ArrayRef[$T]";
}

sub has_param ($@) {
    my $name = shift;
    has $name => (
        is => 'rw',
        traits => [AutoFilterParam],
        predicate => "has_$name",
        clearer => "clear_$name",
        @_,
    );
}

has_param 'action'            => (isa => bunch_of('Str'));
has_param 'actor_id'          => (isa => bunch_of('Int'));
has_param 'person_id'         => (isa => bunch_of('Int'));
has_param 'page_id'           => (isa => bunch_of('Str'));
has_param 'page_workspace_id' => (isa => bunch_of('Int'));
has_param 'tag_name'          => (isa => bunch_of('Str'));

has_param 'before' => (isa => 'Num', sql_builder => '_sb_before');
has_param 'after'  => (isa => 'Num', sql_builder => '_sb_after');

# These params require special implementation so the caller should handle
# them.  SQLSource may have some hints.

has 'followed'  => (is => 'rw', isa => 'Bool');
has 'contributions'  => (is => 'rw', isa => 'Bool');

sub generate_standard_filter {
    my $self = shift;
    my @attrs = grep { $_->does(AutoFilterParam) }
        $self->meta->get_all_attributes;
    return $self->generate_filter(@attrs);
}

sub generate_filter {
    my $self = shift;
    my $meta = $self->meta;

    my @filter;
    for my $field (@_) {
        my $attr = ref($field)
            ? $field
            : $meta->find_attribute_by_name($field);
        croak "unknown param '$field'" unless $attr;
        croak "param '$field' must be handled manually" 
            unless ($attr->does(AutoFilterParam));

        if ($attr->has_sql_builder) {
            my $sb = $attr->sql_builder;
            push @filter, $self->$sb($attr);
        }
        elsif ($attr->has_value($self)) {
            my $val = $attr->get_value($self);
            $val = {-in => $val} if ('ARRAY' eq ref($val));
            push @filter, $field => $val;
        }
    }

    return \@filter;
}

sub _sb_before {
    my $self = shift;
    return $self->_before_after('<',@_);
}

sub _sb_after {
    my $self = shift;
    return $self->_before_after('>',@_);
}

sub _before_after {
    my $self = shift;
    my $op = shift;
    my $attr = shift;
    my $val = $attr->get_value($self);
    return unless $val;
    return 'at' => \[
        "$op 'epoch'::timestamptz + ? * '1 second'::interval",
        $val
    ];
}

__PACKAGE__->meta->make_immutable;
1;
