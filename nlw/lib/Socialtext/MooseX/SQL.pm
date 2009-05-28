package Socialtext::MooseX::SQL;

use Moose;
use Moose::Exporter;

Moose::Exporter->setup_import_methods(
    with_caller => [qw(has_column)],
);

sub init_meta {
    my ($junk, %options) = @_;
    Moose->init_meta(%options);
    Moose::Util::MetaRole::apply_metaclass_roles(
        for_class       => $options{for_class},
        metaclass_roles =>
            ['Socialtext::Moose::Meta::Class::Trait::db_table'],
    );
    return $options{for_class}->meta();
}

sub has_column {
    my ($caller, $name, %options) = @_;

    # add custom Trait to mark it as a DB Column
    $options{traits} ||= [];
    unshift @{ $options{traits} },
        'Socialtext::Moose::Meta::Attribute::Trait::db_column';

    # set default options for DB Columns
    $options{is}  ||= 'rw';
    $options{isa} ||= 'Str';

    Class::MOP::Class->initialize($caller)->add_attribute($name, %options);
}

###############################################################################
{
    package Socialtext::Moose::Meta::Class::Trait::db_table;
    use Moose::Role;
    sub get_all_column_attributes {
        my $self = shift;
        my $column_role = 'Socialtext::Moose::Meta::Attribute::Trait::db_column';
        my @columns;
        foreach my $attr ($self->get_all_attributes) {
            next unless Moose::Util::does_role($attr, $column_role);
            push @columns, $attr;
        }
        return @columns;
    }
}

###############################################################################
{
    package Socialtext::Moose::Meta::Attribute::Trait::db_column;
    use Moose::Role;

    has 'column_name' => (
        is => 'ro', isa => 'Str',
        default => sub { shift->name },
        lazy => 1,
    );

    has 'primary_key' => (
        is => 'ro', isa => 'Bool',
    );

    sub is_primary_key {
        my $self = shift;
        return $self->primary_key;
    }
}

1;

=head1 NAME

Socialtext::MooseX::SQL - Moose sugar for SQL tables

=head1 SYNOPSIS

  ### In your package, defining DB column attributes

  package MyPackage;
  use Moose;
  use Socialtext::MooseX::SQL;

  has_column 'user_id' => (
    isa         => 'Int',
    primary_key => 1,
  );

  has_column 'username' => (
    column_name => 'driver_username',
  );

  ### Get list of all attributes marked as DB columns
  @columns = MyPackage->meta->get_all_column_attributes;

=head1 DESCRIPTION

C<Socialtext::MooseX::SQL> provides some additional syntactic sugar to help
make it easier to define Moose classes that have a DB table sitting underneath
them.

Sugar is provided to help define attributes as columns (C<has_column>), as
well as to get a list of all of the attributes that have been defined as
columns (C<get_all_column_attributes>).

=head1 METHODS

=over

=item B<has_column(PARAMS)>

Like Moose's C<has>, but which applies an attribute trait
C<Socialtext::Moose::Meta::Attribute::Trait::db_column> to signify that this
attribute represents a DB column.

By default, DB columns are defined as:

  is  => 'rw'
  isa => 'Str'

unless otherwise specified via the C<PARAMS>.

The following additional options can be passed through via the C<PARAMS>:

=over

=item column_name

Specifies the name of the DB column.  Defaults to the same name as the
attribute.

=item primary_key

Signifies that this DB column is the primary key for the underlying DB table.

=back

=item B<$class_or_self-E<gt>meta-E<gt>get_all_column_attributes>

Returns a list of attributes which were defined as DB columns using
C<has_column> above.

Is a helper method to short-cut "get me all the attributes and trim that down
to only those that are DB columns".

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
