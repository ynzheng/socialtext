package Socialtext::WebHook;
use Moose;
use Socialtext::Workspace;
use Socialtext::SQL qw/sql_execute sql_singlevalue/;
use Socialtext::SQL::Builder qw/sql_nextval/;
use Carp qw/croak/;
use Socialtext::Page;
use Socialtext::JSON qw/decode_json encode_json/;
use namespace::clean -except => 'meta';

has 'id'           => (is => 'ro', isa => 'Int', required => 1);
has 'creator_id'   => (is => 'ro', isa => 'Int', required => 1);
has 'class'        => (is => 'ro', isa => 'Str', required => 1);
has 'account_id'   => (is => 'ro', isa => 'Int', predecate => 'has_account');
has 'workspace_id' => (is => 'ro', isa => 'Int', predecate => 'has_workspace');
has 'details_blob' => (is => 'ro', isa => 'Str', default => '{}');
has 'url'          => (is => 'ro', isa => 'Str', required => 1);
has 'workspace' => (is => 'ro', isa => 'Object',  lazy_build => 1);
has 'account'   => (is => 'ro', isa => 'Object',  lazy_build => 1);
has 'creator'   => (is => 'ro', isa => 'Object',  lazy_build => 1);
has 'details'   => (is => 'ro', isa => 'HashRef', lazy_build => 1);

sub _build_workspace { die }
sub _build_account { die }
sub _build_creator { die }

sub _build_details {
    my $self = shift;
    return decode_json( $self->details_blob );
}

sub to_hash {
    my $self = shift;
    return {
        map { $_ => $self->$_ }
          qw/id creator_id account_id workspace_id class details url/
    };
}

sub delete {
    my $self = shift;
    sql_execute(q{DELETE FROM webhook WHERE id = ?}, $self->id);
}

# Class Methods

sub ById {
    my $class = shift;
    my $id = shift or die "id is mandatory";

    my $sth = sql_execute(q{SELECT * FROM webhook WHERE id = ?}, $id);
    die "No webhook found with id '$id'" unless $sth->rows;

    my $rows = $sth->fetchall_arrayref({});
    return $class->_new_from_db($rows->[0]);
}

sub Find {
    my $class = shift;
    my %args  = @_;

    my (@bind, @where);
    for my $field (qw/class account_id workspace_id/) {
        if (my $val = $args{$field}) {
            push @where, "$field = ?";
            push @bind, $val;
        }
    }

    my $where = join ' AND ', @where;
    die "Your Find was too loose." unless $where;
    my $sth = sql_execute( "SELECT * FROM webhook WHERE $where", @bind );
    return $class->_rows_from_db($sth);
}

sub Clear {
    sql_execute(q{DELETE FROM webhook});
}

sub All {
    my $class = shift;

    my $sth = sql_execute(q{SELECT * FROM webhook ORDER BY id});
    return $class->_rows_from_db($sth);
}

sub _rows_from_db {
    my $class = shift;
    my $sth   = shift;

    my $results = $sth->fetchall_arrayref({});
    return [ map { $class->_new_from_db($_) } @$results ];
}

sub _new_from_db {
    my $class = shift;
    my $hashref = shift;

    for (qw/account_id workspace_id/) {
        delete $hashref->{$_} unless defined $hashref->{$_};
    }
    return $class->new($hashref);
}

sub Create {
    my $class = shift;
    my %args  = @_;

    my $h = $class->new(
        %args,
        id => sql_nextval('webhook___webhook_id'),
    );
    sql_execute('INSERT INTO webhook VALUES (?,?,?,?,?,?,?)',
        $h->id,
        $h->creator_id,
        $h->class,
        ($h->has_account   ? $h->account_id   : undef ),
        ($h->has_workspace ? $h->workspace_id : undef ),
        $h->details_blob,
        $h->url,
    );
    return $h;
}

__PACKAGE__->meta->make_immutable;
1;
