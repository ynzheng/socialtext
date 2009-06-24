package Test::Socialtext::Rest;
# @COPYRIGHT@
use strict;
use warnings;

use base 'Socialtext::Rest::Entity';
use Socialtext::AppConfig;
use Socialtext::System qw(backtick);
use Socialtext::File qw(get_contents);

(my $nlw = Socialtext::AppConfig->code_base) =~ s{/[^/]+$}{};
my $tests = "$nlw/t/rest_tests";

sub GET {
    my $self = shift;
    my $name = $self->name;
    my $file = "$tests/$name";

    die "$name doesn't exist!\n" unless -f $file;
    return backtick($file) if -x $file;
    return get_contents($file);
}

1;
