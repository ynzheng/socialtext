# @COPYRIGHT@
package Socialtext::File::Stringify::text_rtf;
use strict;
use warnings;

use Socialtext::File::Stringify::Default;
use Socialtext::System;

sub to_string {
    my ( $class, $file ) = @_;
    my $text = Socialtext::System::backtick(
        "unrtf", "--nopict", "--text",
        $file
    );

    if ( $? or $@ ) {
        $text = Socialtext::File::Stringify::Default->to_string($file);
    }
    elsif ( defined $text ) {
        $text =~ s/^.*?-----------------\n//s; # Remove annoying unrtf header.
        $text = Socialtext::File::Stringify::Default->to_string($file) if $?;
    }
    return $text;
}

1;

=head1 NAME

Socialtext::File::Stringify::text_rtf - Stringify RTF documents

=head1 METHODS

=over

=item to_string($filename)

Extracts the stringified content from C<$filename>, an RTF document.

=back

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT

Copyright 2006 Socialtext, Inc., all rights reserved.

=cut
