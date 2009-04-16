package Socialtext::UploadedImage;
use Moose;
use Socialtext::SQL qw/get_dbh :exec :txn/;
use DBD::Pg qw/:pg_types/;
use namespace::clean -except => 'meta';

use constant BINARY_TYPE => {pg_type => PG_BYTEA};

has 'table' => (is => 'ro', isa => 'Str', required => 1);
has 'column' => (is => 'ro', isa => 'Str', required => 1);
has 'id' => (is => 'ro', isa => 'ArrayRef[Str]', required => 1);

has 'image_ref' => (is => 'rw', isa => 'ScalarRef', lazy_build => 1);

for (qw(_keys _vals)) {
    has $_ => (
        is => 'ro', isa => 'ArrayRef', auto_deref => 1,
        lazy_build => 1,
    );
}

sub _build__keys {
    my $id = $_[0]->id;
    return [map { $id->[$_] } grep {$_%2==0} (0..$#$id)];
}
sub _build__vals {
    my $id = $_[0]->id;
    return [map { $id->[$_] } grep {$_%2==1} (0..$#$id)];
}

sub _build_image_ref {
    my $self = shift;
    my $table = $self->table;
    my $col = $self->column;
    my $ph = join(' AND ', map { "$_ = ?" } $self->_keys);
    my $blob = sql_singlevalue(qq{
        SELECT $col FROM $table WHERE $ph
    }, $self->_vals);
    confess "no such image" unless $blob;
    return \$blob;
}

sub load {
    my $self = shift;

    # forces _build_image_ref
    $self->clear_image_ref();
    return $self->image_ref;
}

sub save {
    my $self = shift;

    confess "must have an image_ref to save"
        unless $self->has_image_ref;

    my $table = $self->table;
    my $col = $self->column;

    my @keys = $self->_keys;
    my @vals = $self->_vals;
    my $where_keys = join(' AND ', map { "$_ = ?" } @keys);

    my $dbh = get_dbh();

    my $in_txn = sql_in_transaction();
    sql_begin_work($dbh) unless $in_txn;

    eval {
        local $dbh->{RaiseError} = 1; # b/c of direct $dbh usage

        my ($exists) = $dbh->selectrow_array(qq{
            SELECT 1 FROM $table WHERE $where_keys FOR UPDATE
        }, undef, @vals );

        my $put_sth;
        if ($exists) {
            $put_sth = $dbh->prepare(qq{
                UPDATE $table SET $col = ? WHERE $where_keys
            });
        }
        else {
            my $ins_cols = join(', ', $col, @keys);
            my $ins_phs = join(', ', ('?') x (1+scalar @keys));
            $put_sth = $dbh->prepare(qq{
                INSERT INTO $table ($ins_cols) VALUES ($ins_phs)
            });
        }

        my $n = 1;
        $put_sth->bind_param($n++, ${$self->image_ref}, BINARY_TYPE);
        $put_sth->bind_param($n++, $_) for @vals;

        $put_sth->execute();
        die "unable to update image" unless ($put_sth->rows == 1);

        sql_commit($dbh) unless $in_txn;
    };
    if ($@) {
        sql_rollback($dbh) unless $in_txn;
        die $@;
    }

    return;
}

__PACKAGE__->meta->make_immutable;
1;
