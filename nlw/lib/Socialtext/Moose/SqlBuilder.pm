package Socialtext::Moose::SqlBuilder;
use Moose::Role;

requires 'Builds_sql_for';

sub _get_for_meta {
    my $class = shift;
    Class::MOP::load_class($class->Builds_sql_for);
    return $class->Builds_sql_for->meta;
}

sub Sql_table_name {
    my $class = shift;
    $class->_get_for_meta->table;
}

sub Sql_columns {
    my $class = shift;
    $class->_get_for_meta->get_all_column_attributes();
}

sub Sql_unique_key_columns {
    my $class = shift;
    $class->_get_for_meta->get_unique_key_attributes();
}

sub Sql_pkey_columns {
    my $class = shift;
    $class->_get_for_meta->get_primary_key_attributes();
}

sub Sql_non_pkey_columns {
    my $class = shift;
    my @cols  = grep { !$_->primary_key() } $class->Sql_columns();
    return @cols;
}

no Moose::Role;
1;

=head1 NAME

Socialtext::Moose::SqlBuilder - Syntactic sugar to define classes building SQL

=head1 SYNOPSIS

  package MyFactory;
  use Moose;
  use Socialtext::Moose::SqlBuilder;

  with qw(
      Socialtext::Moose::SqlBuilder::Role::DoesSqlInsert
      Socialtext::Moose::SqlBuilder::Role::DoesSqlSelect
      Socialtext::Moose::SqlBuilder::Role::DoesSqlUpdate
      Socialtext::Moose::SqlBuilder::Role::DoesSqlDelete
  );

  builds_sql_for 'MyTable';

=head1 DESCRIPTION

C<Socialtext::Moose::SqlBuilder> provides some additional syntactic sugar to
help make it easier to set up factory classes that need to build SQL to talk
to an underlying DB.

=head1 METHODS

=over

=item B<builds_sql_for $table_class>

Specifies that this class builds SQL for a DB table that is defined by the
specified C<$table_class>.

It is B<expected> that the provided C<$table_class> has been constructed using
C<Socialtext::Moose::SqlTable>.  This isn't checked for explicitly, but it is
expected.

=back

=head1 COPYRIGHT & LICENSE

Copyright (C) 2009 Socialtext, Inc., All Rights Reserved.

=head1 SEE ALSO

L<Socialtext::Moose::SqlTable>,
L<Socialtext::Moose::SqlBuilder::Role::DoesSqlDelete>,
L<Socialtext::Moose::SqlBuilder::Role::DoesSqlInsert>,
L<Socialtext::Moose::SqlBuilder::Role::DoesSqlSelect>,
L<Socialtext::Moose::SqlBuilder::Role::DoesSqlUpdate>.

=cut
