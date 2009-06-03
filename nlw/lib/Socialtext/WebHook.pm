package Socialtext::WebHook;
use Moose;
use MooseX::Singleton;
use Socialtext::Workspace;
use Socialtext::SQL qw/sql_execute sql_singlevalue/;
use Socialtext::SQL::Builder qw/sql_nextval/;
use Carp qw/croak/;
use Socialtext::Page;
use namespace::clean -except => 'meta';

has 'id'           => (is => 'ro', isa => 'Int', required => 1);
has 'creator_id'   => (is => 'ro', isa => 'Int', required => 1);
has 'class'        => (is => 'ro', isa => 'Str', required => 1);
has 'account_id'   => (is => 'ro', isa => 'Int', required => 1);
has 'workspace_id' => (is => 'ro', isa => 'Int', required => 1);
has 'details_blob' => (is => 'ro', isa => 'Str', required => 1);
has 'url'          => (is => 'ro', isa => 'Str', required => 1);
has 'workspace' => (is => 'ro', isa => 'Object',  lazy_build => 1);
has 'account'   => (is => 'ro', isa => 'Object',  lazy_build => 1);
has 'creator'   => (is => 'ro', isa => 'Object',  lazy_build => 1);
has 'details'   => (is => 'ro', isa => 'HashRef', lazy_build => 1);

sub _build_workspace { die }
sub _build_account { die }
sub _build_creator { die }
sub _build_details { die }

# Class Methods

sub Clear {
    sql_execute(q{DELETE FROM webhook});
}

sub All {
    my $class = shift;
    my $sth = sql_execute(q{SELECT * FROM webhook ORDER BY id});
    my $results = $sth->fetchall_arrayref({});
    my @all;
    for my $r (@$results) {
        push @all, $class->new($r);
    }
    return \@all;
}

sub Add {
    my $class = shift;
    my %opts = @_;
    die "TODO";
    croak 'action is not defined!' unless $opts{action};

    my $workspace_id = $opts{workspace} ? $opts{workspace}->workspace_id 
                                        : undef;
    my $page_id = undef;
    if (my $name = $opts{page_id}) {
        my $page = Socialtext::Page->new;
        $page_id = $page->name_to_id($name);
    }

    sql_execute('INSERT INTO webhook VALUES (?, ?, ?, ?)',
        sql_nextval('webhook___webhook_id'),
        $workspace_id,
        $opts{action},
        $page_id,
    );
}

__PACKAGE__->meta->make_immutable;
1;
