package Socialtext::Moose::SqlBuilder::Role::DoesSqlSelect;

use Moose::Role;
with qw(
    Socialtext::Moose::SqlBuilder::Role::DoesIdentifiesUniqueRecord
);
use Carp qw(croak);
use Socialtext::SQL::Builder qw(sql_abstract);
use Socialtext::SQL qw(sql_execute);

sub SqlSelect {
    my $self = shift;
    my $opts = shift;

    my $cols   = $opts->{columns} || '*';
    my $where  = $opts->{where};
    my $order  = $opts->{order};
    my $limit  = $opts->{limit};
    my $offset = $opts->{offset};

    my $table_class = $self->meta->sql_table_class();
    my $table       = $table_class->meta->table();
    my $builder     = sql_abstract();
    my ($sql, @bindings) = $builder->select(
        $table, $cols, $where, $order, $limit, $offset
    );
    return sql_execute($sql, @bindings);
}

sub SqlSelectOneRecord {
    my $self = shift;
    my $opts = shift;

    my $where = $opts->{where};
    unless ($self->IdentifiesUniqueRecord($where)) {
        croak "Cannot accurately identify unique record to retrieve; aborting";
    }
    return $self->SqlSelect($opts);
}

no Moose::Role;
1;

=head1 NAME

Socialtext::Moose::SqlBuilder::Role::DoesSqlSelect - SQL SELECT Moose Role

=head1 SYNOPSIS

  $sth = MyFactory->SqlSelect( {
      columns => [qw( user_id driver_key driver_unique_id )],
      where   => {
          first_name => 'john',
          last_name  => 'doe',
      },
      order   => 'user_id',
      limit   => 10,
      offset  => 0,
  } );

  $sth = MyFactory->SqlSelectOneRecord( {
      where => {
          user_id => 123,
      },
  } );

=head1 DESCRIPTION

C<Socialtext::Moose::SqlBuilder::Role::DoesSqlSelect> implements a C<Moose>
Role which allows for the generation and execution of SQL SELECT statements
against an underlying DB table.

=head1 METHODS

=over

=item B<$class-E<gt>SqlSelect(\%opts)>

Issues a SQL C<SELECT> against the DB, and returns a DBI Statement Handle back
to the caller.

C<SqlSelect> accepts a number of options, which in turn are then passed
through to C<SQL::Abstract::Limit>:

=over

=item columns

Specifies the DB columns that are to be selected.  Defaults to "*" unless
specified.

=item where

Specifies the C<SQL::Abstract> WHERE clause.

=item order

Specifies any specific ordering you require on the results.

=item limit

Specifies a maximum limit on the number of results that are to be returned.

=item offset

Specifies the offset into the result set from which search results should be
retrieved.

=back

=item B<$class-E<gt>SqlSelectOneRecord(\%opts)>

Issues a SQL C<SELECT> against the DB (like C<SqlSelect()> above), with the
expectation that the provided WHERE clause contains enough information to
B<uniquely> identify a single record in the DB.

If the provided WHERE clause cannot identify a unique record, this method
throws a fatal exception.

=back

=head1 COPYRIGHT & LICENSE

Copyright (C) 2009 Socialtext, Inc., All Rights Reserved.

=head1 SEE ALSO

L<Socialtext::Moose::SqlBuilder>,
L<SQL::Abstract>,
L<SQL::Abstract::Limit>.

=cut
