package Socialtext::Moose::SqlBuilder::Role::DoesIdentifiesUniqueRecord;

use Moose::Role;
use List::MoreUtils qw(all);

requires 'Sql_unique_key_columns';

sub IdentifiesUniqueRecord {
    my $self  = shift;
    my $where = shift;

    foreach my $key ($self->Sql_unique_key_columns) {
        my $have_all_attrs = all { exists $where->{ $_->name } } @{$key};
        return 1 if ($have_all_attrs);
    }
    return 0;
}

no Moose::Role;
1;

=head1 NAME

Socialtext::Moose::SqlBuilder::Role::DoesIdentifiesUniqueRecord - Does the WHERE clause identify a unique record?

=head1 SYNOPSIS

  unless (MyFactory->IdentifiesUniqueRecord( \%where )) {
      # hash-ref doesn't contain enough info to identify unique record
  }

=head1 DESCRIPTION

C<Socialtext::Moose::SqlBuilder::Role::DoesIdentifiesUniqueRecord> implements
a C<Moose> role which helps determine if a provided SQL WHERE clause is
capable of identifying a single unique record in the DB (based on the
definition of the DbTable class).

=head1 METHODS

=over

=item B<$class-E<gt>IdentifiesUniqueRecord(\%where)>

Checks to see if the provided C<\%where> clause is capable of identifying a
unique record in the DB.  Returns true if it is, false otherwise.

B<NOTE:> this isn't a highly stringent check; we check to make sure that the
WHERE clause contains enough columns to at least satisfy one of the unique
indices on the DB, but we B<aren't> expanding out the WHERE clause to make
sure that you're not passing in list of values to check against (e.g. "WHERE
foo IN (...)").

=back

=head1 COPYRIGHT & LICENSE

Copyright (C) 2009 Socialtext, Inc., All Rights Reserved.

=head1 SEE ALSO

L<Socialtext::Moose::SqlBuilder>.

=cut
