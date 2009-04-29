# @COPYRIGHT@
package Socialtext::File::Stringify::text_html;
use strict;
use warnings;

use Socialtext::File::Stringify::Default;
use Socialtext::System;

sub to_string {
    my ( $class, $file ) = @_;
    my @cmd = "lynx";

    if (-x '/usr/bin/elinks') {
        warn "USING ELINKS\n";
        @cmd = qw(/usr/bin/elinks -config-file /dev/null);
    }

    push @cmd, '-dump' => $file;
    my $text = Socialtext::System::backtick(@cmd);
    $text = Socialtext::File::Stringify::Default->to_string($file) if $? or $@;
    return $text;
}

1;
