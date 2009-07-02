package Test::Socialtext::Rest;
# @COPYRIGHT@
use strict;
use warnings;

use base 'Socialtext::Rest::Entity';
use Socialtext::AppConfig;
use Socialtext::System qw(backtick);
use Socialtext::File qw(get_contents_utf8);

(my $nlw = Socialtext::AppConfig->code_base) =~ s{/[^/]+$}{};
my $files = "$nlw/t/rest_files";

sub GET {
    my $self = shift;
    my $name = $self->name;
    my $file = "$files/$name";

    $self->rest->header('-type', 'text/plain; charset=UTF-8');

    die "$name doesn't exist!\n" unless -f $file;
    return backtick($file) if -x $file;
    return get_contents_utf8($file);
}

1;

__END__

=head1 NAME

Test::Socialtext::Rest - An extension to the rest API for tests

=head1 SYNOPSIS

GET /data/test/:file_or_script

=head1 DESCRIPTION

This module provides a method for testing HTTP and HTTPS connections. When perform a GET on /data/test/filename, the contents of t/rest_files/filename are returned. However, if file is executable, the data printed to STDOUT is returned rather than the contents of the file.

=cut
