# @COPYRIGHT@
package Socialtext::File::Stringify::application_zip;
use strict;
use warnings;

use File::Find;
use File::Path;
use File::Temp;

use Socialtext::File::Stringify;
use Socialtext::File::Stringify::Default;
use Socialtext::System;

sub to_string {
    my ( $class, $file ) = @_;

    # Unpack the zip file in a temp dir.
    my $tempdir = File::Temp::tempdir( CLEANUP => 1 );
    Socialtext::System::backtick( "unzip", '-P', '', "-q", $file, "-d", $tempdir );
    return _default($file) if $@;

    # Find all the files we unpacked.
    my @files;
    find sub {
        push @files, $File::Find::name if -f $File::Find::name;
    }, $tempdir;

    # Stringify each the files we found
    my $zip_text = "";
    for my $f (@files) {
        my $text = Socialtext::File::Stringify->to_string($f);
        $zip_text .= "\n\n========== $f ==========\n\n" . $text if $text;
    }

    # Cleanup and return the text if we got any, 'else use the default.
    File::Path::rmtree($tempdir);
    return $zip_text || _default($file);
}

sub _default {
    my $file = shift;
    return Socialtext::File::Stringify::Default->to_string($file)
}

1;

=head1 NAME

Socialtext::File::Stringify::application_zip - Stringify contents of Zip files

=head1 METHODS

=over

=item to_string($filename)

Recursively extracts the stringified content of B<all> of the documents
contained within the given C<$filename>, a Zip archive.

=back

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT

Copyright 2006 Socialtext, Inc., all rights reserved.

=cut
