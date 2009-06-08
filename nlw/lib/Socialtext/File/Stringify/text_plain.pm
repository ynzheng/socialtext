# @COPYRIGHT@
package Socialtext::File::Stringify::text_plain;
use strict;
use warnings;

use Socialtext::File;
use Socialtext::l10n qw(system_locale);

sub to_string {
    my ( $class, $filename ) = @_;
    my $text = '';
    eval {
        my $encoding = Socialtext::File::get_guess_encoding(system_locale(), $filename);
        $text = scalar Socialtext::File::get_contents_based_on_encoding($filename, $encoding);
    };
    if ($@) {
        $text = Socialtext::File::get_contents($filename);
    }
    return $text;
}

1;

=head1 NAME

Socialtext::File::Stringify::text_plain - Stringify text documents

=head1 METHODS

=over

=item to_string($filename)

Extracts the stringified content from C<$filename>, a text document.

=back

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT

Copyright 2006 Socialtext, Inc., all rights reserved.

=cut
