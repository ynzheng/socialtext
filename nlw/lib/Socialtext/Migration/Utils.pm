package Socialtext::Migration::Utils;
# @COPYRIGHT@
use strict;
use warnings;
use Socialtext::Schema;
use base 'Exporter'; 
our @EXPORT_OK = qw/socialtext_schema_version ensure_socialtext_schema/;

sub socialtext_schema_version {
    my $schema = Socialtext::Schema->new;
    return $schema->current_version;
}

sub ensure_socialtext_schema {
    my $max_version = shift || die 'A maximum version number is mandatory';

    my $schema = Socialtext::Schema->new;
    return if $schema->current_version >= $max_version;

    print "Ensuring socialtext schema is at version $max_version\n";
    $schema->sync( to_version => $max_version );
}

1;
