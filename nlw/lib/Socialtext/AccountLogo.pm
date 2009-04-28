package Socialtext::AccountLogo;
# @COPYRIGHT@
use Moose;
use File::Spec;
use File::Temp qw/tempfile/;
use Socialtext::File;
use Socialtext::Skin;
use Socialtext::Paths;
use Socialtext::Image;
use namespace::clean -except => 'meta';

has 'account' => (
    is => 'ro', isa => 'Socialtext::Account',
    required => 1,
    weak_ref => 1,
    handles => [qw(account_id)],
);
has 'uploaded' => (
    is => 'ro', isa => 'Socialtext::UploadedImage',
    lazy_build => 1,
);
has '_is_default_logo' => (
    is => 'rw', isa => 'Bool', default => undef,
);

sub _build_uploaded {
    my $self = shift;

    my $default = Socialtext::Account->Default();
    my $is_default = ($default->account_id == $self->account_id);

    return Socialtext::UploadedImage->new(
        table => 'account_logo',
        column => 'logo',
        id => [ account_id => $self->account_id ],
        ($is_default) ? (alternate_ids => {account_id => [0]}) : (),
    );
}

sub is_default_logo {
    my $self = shift;
    $self->load() unless ($self->logo->has_image_ref);
    return $self->_is_default_logo;
}

sub load {
    my $self = shift;
    my $uploaded = $self->uploaded; 
    eval { $uploaded->load() };
    if ($@) {
        my $new_ref = \( $self->Default_logo() );
        $self->_is_default_logo(1);
        $uploaded->image_ref($new_ref);
    }
    return $uploaded->image_ref;
}

sub _transform_image {
    my $self = shift;
    my $image_ref = shift;

    # TODO: resize $image_ref 
    my ($fh, $filename) = tempfile;
    print $fh $$image_ref;
    close $fh or die "Could not process image: $!";

    Socialtext::Image::extract_rectangle(
        image_filename => $filename,
        width => 201,
        height => 36,
    );

    my $txfrm_image = Socialtext::File::get_contents_binary($filename);
    return \$txfrm_image;
}

sub save_image {
    my $self = shift;
    my $image_ref = shift;

    my $uploaded = $self->uploaded;

    my $txfrm_image_ref = $self->_transform_image($image_ref);

    $uploaded->image_ref($txfrm_image_ref);
    $uploaded->save();
    return $self->cache_image();
}

sub cache_image {
    my $self = shift;
    my $cache_dir = $self->Cache_dir();
    my $lock_fh = Socialtext::File::write_lock("$cache_dir/.lock");
    $self->uploaded->cache_to_dir($cache_dir);
}

sub Cache_dir {
    my $class = shift;   
    my $cache_dir = Socialtext::Paths::cache_directory('account_logo');
    Socialtext::File::ensure_directory($cache_dir);

    return $cache_dir;
}

sub remove {
    my $self = shift;
    my $uploaded = $self->uploaded;
    my $dir = $self->Cache_dir;
    $uploaded->remove;
    my $lock_fh = Socialtext::File::write_lock("$dir/.lock");
    $uploaded->remove_cache($dir);
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
