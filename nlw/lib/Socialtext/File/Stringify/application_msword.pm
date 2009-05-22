# @COPYRIGHT@
package Socialtext::File::Stringify::application_msword;
use strict;
use warnings;

use File::Temp;
use Socialtext::File;
use Socialtext::File::Stringify::Default;
use Socialtext::System qw/backtick/;
use Socialtext::Log qw/st_log/;

sub to_string {
    my ( $class, $filename ) = @_;

    my ( undef, $temp_filename ) = File::Temp::tempfile(
        Socialtext::File::temp_template_for('indexing_word_attachment'),
        CLEANUP => 1,
    );

    # If 'wvText' fails, fall back on the "any' mode.
    my $ignored = backtick('wvText', $filename, $temp_filename);
    if (my $err = $@) {
        st_log->warning("Failed to index $filename: $err");
        return Socialtext::File::Stringify::Default->to_string($filename);
    }
    else {
        return Socialtext::File::get_contents_utf8($temp_filename)
    }
}

1;
