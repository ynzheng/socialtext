package Socialtext::AccountLogo;
# @COPYRIGHT@
use Moose;
use Socialtext::File;
use Socialtext::Skin;
use File::Spec;
use Socialtext::Paths;
use namespace::clean -except => 'meta';

has 'account' => (
    is => 'ro', isa => 'Socialtext::Account',
    required => 1,
    weak_ref => 1,
    handles => [qw(account_id)],
);
has 'logo' => (
    is => 'ro', isa => 'Socialtext::UploadedImage',
    lazy_build => 1,
);

sub _build_logo {
    my $self = shift;

    return Socialtext::UploadedImage->new(
        table => 'account_logo',
        column => 'logo',
        id => [ account_id => $self->account_id ],
    );
}

sub load {
    my $self = shift;
    my $logo = $self->logo; 
    eval { $logo->load() };
    if ($@) {
        my $new_ref = \( $self->Default_logo() );
        $logo->image_ref($new_ref);
    }
    return $logo->image_ref;
}

sub save_image {
    my $self = shift;
    my $image_ref = shift;

    my $logo = $self->logo;

    # TODO: resize $image_ref 
    my $txfrm_image_ref = $image_ref;

    $logo->image_ref($txfrm_image_ref);
    $logo->save();

    return $self->cache_image();
}

sub cache_image {
    my $self = shift;
    my $cache_dir = Socialtext::Paths::cache_directory('account_logo');
    Socialtext::File::ensure_directory($cache_dir);
    $self->logo->cache_to_dir($cache_dir);
}

sub Default_logo_name {
    my $class = shift;

    # get the path to the image, on *disk*
    my $skin = Socialtext::Skin->new( name => 's3' );
    my $loc = File::Spec->catfile(
        $skin->skin_path,
        "images/logo.png",
    );

    return $loc;
}

sub Default_logo {
    my $class = shift;
    return scalar Socialtext::File::get_contents_binary(
        $class->Default_logo_name()
    );
}

__PACKAGE__->meta->make_immutable;
