package Test::Socialtext::Rest;
# @COPYRIGHT@
use strict;
use warnings;

use base 'Socialtext::Rest::Entity';
use Socialtext::AppConfig;
use Socialtext::System qw(backtick);
use Socialtext::File qw(get_contents);

(my $nlw = Socialtext::AppConfig->code_base) =~ s{/[^/]+$}{};
my $files = "$nlw/t/rest_files";

sub GET {
    my $self = shift;
    my $name = $self->name;
    my $file = "$files/$name";

    die "$name doesn't exist!\n" unless -f $file;
    return backtick($file) if -x $file;
    return get_contents($file);
}

1;
