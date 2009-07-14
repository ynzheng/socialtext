package Socialtext::Moose::SqlBuilder::Role::DoesSqlDelete;

use Moose::Role;
with qw(
    Socialtext::Moose::SqlBuilder::Role::DoesIdentifiesUniqueRecord
);

use Carp;
use Socialtext::SQL::Builder qw(sql_abstract);
use Socialtext::SQL qw(sql_execute);

sub SqlDelete {
    my $self  = shift;
    my $where = shift;

    my $table_class = $self->meta->sql_table_class();
    my $table       = $table_class->meta->table();
    my $builder     = sql_abstract();
    my ($sql, @bindings) = $builder->delete(
        $table, $where,
    );
    return sql_execute($sql, @bindings);
}

sub SqlDeleteOneRecord {
    my $self  = shift;
    my $where = shift;

    unless ($self->IdentifiesUniqueRecord($where)) {
        croak "Cannot accurately identify unique record to delete; aborting";
    }
    return $self->SqlDelete($where);
}

no Moose::Role;
1;

=head1 NAME

Socialtext::Moose::SqlBuilder::Role::DoesSqlDelete - SQL DELETE Moose Role

=head1 SYNOPSIS

  $sth = MyFactory->SqlDelete( {
      email_address => 'john.doe@example.com',
  } );

  $sth = MyFactory->SqlDeleteOneRecord( {
      user_id => 123,
  } );

=head1 DESCRIPTION

C<Socialtext::Moose::SqlBuilder::Role::DoesSqlDelete> implements a C<Moose>
Role which allows for the generation and execution of SQL DELETE statements
against an underlying DB table.

=head1 METHODS

=over

=item B<$class-E<gt>SqlDelete(\%where)>

Issues a SQL C<DELETE> against the DB, and returns a DBI Statement Handle back
to the caller.  The provided hash-ref C<\%where> clause should be suitable for
handing to C<SQL::Abstract>.

=item B<$class-E<gt>SqlDeleteOneRecord(\%where)>

Issues a SQL C<DELETE> against the DB (like C<SqlDelete()> above), with the
expectation that the provided C<\%where> clause contains enough information to
B<uniquely> identify a single record in the DB.

If the provided WHERE clause cannot identify a unique record, this method
throws a fatal exception.

=back

=head1 COPYRIGHT & LICENSE

Copyright (C) 2009 Socialtext, Inc., All Rights Reserved.

=head1 SEE ALSO

L<Socialtext::Moose::SqlBuilder>,
L<Socialtext::Moose::SqlBuilder::Role::DoesIdentifiesUniqueRecord>,
L<SQL::Abstract>.

=cut
