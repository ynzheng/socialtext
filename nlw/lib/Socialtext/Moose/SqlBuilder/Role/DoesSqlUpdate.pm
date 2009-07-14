package Socialtext::Moose::SqlBuilder::Role::DoesSqlUpdate;

use Moose::Role;
with qw(
    Socialtext::Moose::SqlBuilder::Role::DoesIdentifiesUniqueRecord
);

use Carp;
use Socialtext::SQL::Builder qw(sql_abstract);
use Socialtext::SQL qw(sql_execute);

sub SqlUpdate {
    my $self = shift;
    my $opts = shift;

    my $values = $opts->{values};
    my $where  = $opts->{where};

    my $table_class = $self->meta->sql_table_class();
    my $table       = $table_class->meta->table();
    my $builder     = sql_abstract();
    my ($sql, @bindings) = $builder->update(
        $table, $values, $where,
    );
    return sql_execute($sql, @bindings);
}

sub SqlUpdateOneRecord {
    my $self = shift;
    my $opts = shift;

    my $where = $opts->{where};
    unless ($self->IdentifiesUniqueRecord($where)) {
        croak "Cannot accurately identify unique record to update; aborting";
    }
    return $self->SqlUpdate($opts);
}

no Moose::Role;
1;

=head1 NAME

Socialtext::Moose::SqlBuilder::Role::DoesSqlUpdate - SQL UPDATE Moose Role

=head1 SYNOPSIS

  $sth = MyFactory->SqlUpdate( {
      values => {
          primary_account_id => 2,
      },
      where  => {
          primary_account_id => 1,
      },
  } );

  $sth = MyFactory->SqlUpdateOneRecord( {
      values => {
          email_address => 'john.doe@example.com',
      },
      where  => {
          user_id => 123,
      },
  } );

=head1 DESCRIPTION

C<Socialtext::Moose::SqlBuilder::Role::DoesSqlUpdate> implements a C<Moose>
Role which allows for the generation and execution of SQL UPDATE statements
against an underlying DB table.

=head1 METHODS

=over

=item B<$class-E<gt>SqlUpdate(\%opts)>

Issues a SQL C<UPDATE> against the DB, and returns a DBI Statement Handle back
to the caller.

The provided hash-ref of C<\%opts> may contain:

=over

=item values

A hash-ref of the new values that the record is to be updated to.

=item where

A hash-ref containing a WHERE clause, suitable for handing to
C<SQL::Abstract>.

=back

=item B<$class-E<gt>SqlUpdateOneRecord(\%opts)>

Issues a SQL C<UPDATE> against the DB (like C<SqlUpdate()> above), with the
expectation that the provided WHERE clause contains enough information to
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
