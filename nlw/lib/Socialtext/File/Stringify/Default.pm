# @COPYRIGHT@
package Socialtext::File::Stringify::Default;
use strict;
use warnings;

use Socialtext::System;
use MIME::Types;

sub to_string {
    my ( $class, $filename ) = @_;
    my $mime = MIME::Types->new->mimeTypeOf($filename) || "";

    # These produce huge output that is 99% not useful, so just do nothing.
    return "" if $mime =~ m{^(image|video|audio)/.*};  

    return Socialtext::System::backtick( 'strings', $filename );
}

1;

=head1 NAME

Socialtext::File::Stringify::Default - Default stringifier

=head1 DESCRIPTION

Default stringifier, when nothing else is willing to handle it.

=head1 METHODS

=over

=item to_string($filename)

Extracts the stringified content from C<$filename>, using F<strings>.

=back

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT

Copyright 2006 Socialtext, Inc., all rights reserved.

=cut
