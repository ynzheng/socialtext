package Socialtext::Moose::SqlBuilder::Role::DoesColumnFiltering;

use Moose::Role;

sub FilterColumns {
    my $self   = shift;
    my $proto  = shift;
    my $filter = shift;

    my $table_class = $self->meta->sql_table_class();
    my $table_meta  = $table_class->meta();
    my %valid =
        map  { $_ => $proto->{$_} }
        grep { exists $proto->{$_} }
        map  { $_->name }
        grep { $filter->($_) }
        $table_meta->get_all_column_attributes;

    return \%valid;
}

sub FilterValidColumns {
    my $self  = shift;
    my $proto = shift;
    return $self->FilterColumns(
        $proto,
        sub { 1 },
    );
}

sub FilterPrimaryKeyColumns {
    my $self  = shift;
    my $proto = shift;
    return $self->FilterColumns(
        $proto,
        sub { $_->primary_key },
    );
}

sub FilterNonPrimaryKeyColumns {
    my $self  = shift;
    my $proto = shift;
    return $self->FilterColumns(
        $proto,
        sub { not $_->primary_key },
    );
}

no Moose::Role;
1;

=head1 NAME

Socialtext::Moose::SqlBuilder::Role::DoesColumnFiltering - Filter Db Table column data

=head1 SYNOPSIS

  # filter to include only key/value pairs for valid columns
  $valid = MyFactory->FilterValidColumns( $data );

  # filter to include only key/value pairs for primary key columns
  $pkey = MyFactory->FilterPrimaryKeyColumns( $data );

  # filter to include only key/value pairs for NON primary key columns
  $non_pkey = MyFactory->FilterPrimaryKeyColumns( $data );

  # generic filter
  $filtered = MyFactory->FilterGeneric( $data, sub { $_->is_required } );

=head1 DESCRIPTION

C<Socialtext::Moose::SqlBuilder::Role::DoesColumnFiltering> implements a
series of methods to help filter data sets that are to be used in/with a
DbTable.

=head1 METHODS

=over

=item B<$class-E<gt>FilterValidColumns( \%data )>

Filters the provided hash-ref of C<\%data>, returning a hash-ref that contains
only those field/value pairs which are for columns in the Db Table we're
managing.

=item B<$class-E<gt>FilterPrimaryKeyColumns( \%data )>

Filters the provided hash-ref of C<\%data>, returning a hash-ref that contains
only those field/value pairs which are for columns that comprise the primary
key of the Db Table we're managing.

=item B<$class-E<gt>FilterNonPrimaryKeyColumns( \%data )>

Filters the provided hash-ref of C<\%data>, returning a hash-ref that contains
only those field/value pairs which are for columns that are B<NOT> part of the
primary key of the Db Table we're managing.

=item B<$class-E<gt>FilterGeneric( \%data, $coderef )>

Filters the provided hash-ref of C<\%data>, using the provided C<$coderef> to
C<grep> for the attributes that we are concerned with.  Returns a hash-ref of
the field/value pairs that match the filtering condition implemented by the
C<$coderef>.

=back

=head1 COPYRIGHT & LICENSE

Copyright (C) 2009 Socialtext, Inc., All Rights Reserved.

=head1 SEE ALSO

L<Socialtext::Moose::SqlBuilder>.

=cut
