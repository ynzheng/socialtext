package Socialtext::AccountLogo;
# @COPYRIGHT@
use Moose;
use Socialtext::File;
use Socialtext::Skin;
use File::Spec;
use Socialtext::Paths;
use Socialtext::Image;
use File::Temp qw/tempfile/;
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

sub _transform_image {
    my $self = shift;
    my $image_ref = shift;

    # TODO: resize $image_ref 
    my ($fh, $filename) = tempfile;
    print $fh $$image_ref;
    close $fh or die "Could not process image: $!";

    Socialtext::Image::constrain_and_fill_image(
        image_filename => $filename,
        width => 201,
        height => 36,
        fill_color => 'rgba(235,246,250,0.0)', # transparent '#EBF6FA',
        #fill_color => 'rgba(255,0,0,0.5)',
    );

    my $txfrm_image = Socialtext::File::get_contents_binary($filename);
    return \$txfrm_image;
}

sub save_image {
    my $self = shift;
    my $image_ref = shift;

    my $logo = $self->logo;

    my $txfrm_image_ref = $self->_transform_image($image_ref);

    $logo->image_ref($txfrm_image_ref);
    $logo->save();
    return $self->cache_image();
}

sub cache_image {
    my $self = shift;
    my $cache_dir = $self->Cache_dir();
    # TODO: if this account is the default, write the image for account_id
    # 0 as well.
    $self->logo->cache_to_dir($cache_dir);
}

sub Cache_dir {
    my $class = shift;   
    my $cache_dir = Socialtext::Paths::cache_directory('account_logo');
    Socialtext::File::ensure_directory($cache_dir);

    return $cache_dir;
}

sub remove {
    my $self = shift;
    my $logo = $self->logo;
    $logo->remove;
    # TODO: if this account is the default, remove the image for account_id 0
    # as well.
    $logo->remove_cache( $self->Cache_dir );
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
