# @COPYRIGHT@
package Socialtext::File::Stringify::application_vnd_ms_powerpoint;
use strict;
use warnings;

use Socialtext::File::Stringify::Default;
use Socialtext::System;

sub to_string {
    my ( $class, $file ) = @_;
    my $text = Socialtext::System::backtick( "catppt",  $file );
    if ( $? or $@ ) {
        $text = Socialtext::File::Stringify::Default->to_string($file);
    }
    
    return $text;
}

1;

=head1 NAME

Socialtext::File::Stringify::application_vnd_ms_powerpoint - Stringify MS Powerpoint documents

=head1 METHODS

=over

=item to_string($filename)

Extracts the stringified content from C<$filename>, an MS Powerpoint document.

=back

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT

Copyright 2006 Socialtext, Inc., all rights reserved.

=cut
