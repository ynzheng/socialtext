package Socialtext::Moose::SqlBuilder;

use Moose;
use Moose::Exporter;

use Socialtext::Moose::SqlBuilder::Meta::Class::Trait::SqlBuilder;

Moose::Exporter->setup_import_methods(
    with_caller => [qw( builds_sql_for )],
);

sub init_meta {
    my ($junk, %options) = @_;
    Moose->init_meta(%options);
    Moose::Util::MetaRole::apply_metaclass_roles(
        for_class => $options{for_class},
        metaclass_roles => [qw( Socialtext::Moose::SqlBuilder::Meta::Class::Trait::SqlBuilder )],
    );
    return $options{for_class}->meta();
}

sub builds_sql_for {
    my ($caller, $name) = @_;
    $caller->meta->sql_table_class($name);
}

no Moose;
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
