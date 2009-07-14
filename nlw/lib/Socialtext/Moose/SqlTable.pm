package Socialtext::Moose::SqlTable;

use Moose;
use Moose::Exporter;

use Socialtext::Moose::SqlTable::Meta::Class::Trait::DbTable;
use Socialtext::Moose::SqlTable::Meta::Attribute::Trait::DbColumn;

Moose::Exporter->setup_import_methods(
    with_caller => [qw( has_column has_table has_unique_key )],
);

sub init_meta {
    my ($junk, %options) = @_;
    Moose->init_meta(%options);
    Moose::Util::MetaRole::apply_metaclass_roles(
        for_class       => $options{for_class},
        metaclass_roles => [qw( Socialtext::Moose::SqlTable::Meta::Class::Trait::DbTable )],
    );
    Moose::Util::MetaRole::apply_base_class_roles(
        for_class => $options{for_class},
        roles     => [qw( Socialtext::Moose::SqlTable::Role::SqlTable )],
    );
    return $options{for_class}->meta();
}

sub has_column {
    my ($caller, $name, %options) = @_;

    # add Trait to mark this as a DbColumn
    $options{traits} ||= [];
    unshift @{$options{traits}}, 'Socialtext::Moose::SqlTable::Meta::Attribute::Trait::DbColumn';

    Class::MOP::Class->initialize($caller)->add_attribute($name, %options);
}

sub has_table {
    my ($caller, $name) = @_;
    $caller->meta->table($name);
}

sub has_unique_key {
    my ($caller, @attr_names) = @_;
    my $keys = $caller->meta->unique_keys();
    push @{$keys}, [@attr_names];
    $caller->meta->unique_keys($keys);
}

no Moose;
1;

=head1 NAME

Socialtext::Moose::SqlTable - Syntactic sugar to define DB Tables

=head1 SYNOPSIS

  package MyTable;
  use Moose;
  use Socialtext::Moose::SqlTable;

  has_table 'my_db_table';
  has_unique_key qw(driver_key driver_unique_id);

  has_column 'my_id' => (
      is          => 'rw',
      isa         => 'Int',
      primary_key => 1,
  );

  has_column 'driver_key' => (
      is       => 'rw',
      isa      => 'Str',
      required => 1,
  );

  has_column 'driver_unique_id' => (
      is       => 'rw',
      isa      => 'Str',
      required => 1,
  );


=head1 DESCRIPTION

C<Socialtext::Moose::SqlTable> provides some additional syntactic sugar to
help make it easier to set up data classes that have an underlying DB table.

=head1 METHODS

=over

=item B<has_column ...>

Similar to C<has> (as provided by C<Moose>), but which automatically sets up
an appropriate trait on the attribute, marking it as being a DbColumn.

DbColumns have an additional attribute which can be set, to help signify that
the column is part of the C<primary_key> for the table.  Attributes that are
marked as being part of the primary key are also treated as being B<required>
attributes.

=item B<has_table $db_table>

Specifies that this class operates against the specified C<$db_table>.

=item B<has_unique_key qw(attr_name1 attr_name2 ...)>

Defines an alternate unique key, comprised of the provided list of attribute
names.

Multiple unique keys can be defined; simply call this method once for each
unique key you wish to define and it'll DTRT.

=back

=head1 COPYRIGHT & LICENSE

Copyright (C) 2009 Socialtext, Inc., All Rights Reserved.

=head1 SEE ALSO

L<Socialtext::Moose::SqlTable::Role::SqlTable>,
L<Socialtext::Moose::SqlTable::Meta::Class::Trait::DbTable>,
L<Socialtext::Moose::SqlTable::Meta::Attribute::Trait::DbColumn>.

=cut
