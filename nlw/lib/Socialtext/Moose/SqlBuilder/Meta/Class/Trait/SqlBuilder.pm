package Socialtext::Moose::SqlBuilder::Meta::Class::Trait::SqlBuilder;

use Moose::Role;

has 'sql_table_class' => (
    is  => 'rw',
    isa => 'Str',
);

no Moose::Role;
1;

=head1 NAME

Socialtext::Moose::SqlBuilder::Meta::Class::Trait::SqlBuilder - SqlBuilder class trait

=head1 SYNOPSIS

  # get the name of the class that implements the Db Table
  $table_class = MyBuilder->meta->sql_table_class();

=head1 DESCRIPTION

C<Socialtext::Moose::SqlBuilder::Meta::Class::Trait::SqlBuilder> provides a
C<Moose> class trait to assist in building classes that generate SQL for other
classes which have DB tables.

=head1 METHODS

=over

=item B<$class-E<gt>metaE<gt>sql_table_class()>

Sets/queries the name of the class which implements the DbTable that we are
building SQL for.

=back

=head1 COPYRIGHT & LICENSE

Copyright (C) 2009 Socialtext, Inc., All Rights Reserved.

=head1 SEE ALSO

L<Socialtext::Moose::SqlBuilder>,
L<Socialtext::Moose::SqlTable>.

=cut
