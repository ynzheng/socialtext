# @COPYRIGHT@
package Socialtext::Image;
use strict;
use warnings;

use Socialtext::System qw(shell_run backtick);
use Carp ();
use Readonly;
use IO::Handle;
use IO::File;
use Socialtext::Validate qw( validate SCALAR_TYPE OPTIONAL_INT_TYPE HANDLE_TYPE );

{
    Readonly my $spec => {
        max_width  => OPTIONAL_INT_TYPE,
        max_height => OPTIONAL_INT_TYPE,
        new_width  => OPTIONAL_INT_TYPE,
        new_height => OPTIONAL_INT_TYPE,
        filename   => SCALAR_TYPE( default => '' ),
        blob       => SCALAR_TYPE( default => '' ),
    };

    sub resize {
        my %p = validate( @_, $spec );

        my $file = $p{filename} || die "Filename is required";

        ($p{img_width}, $p{img_height}) = split ' ', `identify -format '\%w \%h' $file`;
        my ($new_width, $new_height) = get_proportions(%p);

        if ($new_width and $new_height) {
            local $Socialtext::System::SILENT_RUN = 1;
            convert($file, $file, scale => "${new_width}x${new_height}");
        }
    }
}

sub shrink {
    my ($w,$h,$max_w,$max_h) = @_;
    my $over_w = $max_w ? $w / $max_w : 0;
    my $over_h = $max_h ? $h / $max_h : 0;
    if ($over_w > 1 and $over_w > $over_h) {
        $w /= $over_w;
        $h /= $over_w;
    }
    elsif ($over_h > 1 and $over_h >= $over_w) {
        $w /= $over_h;
        $h /= $over_h;
    }
    return ($w,$h);
}

# crop an image using an internal, centered rectangle of the desired size
sub extract_rectangle {
    my %p = @_;

    die "an 'image_filename' filename parameter is required"
        unless $p{image_filename};

    my $img = $p{image_filename};
    my ($max_w, $max_h) = @p{qw(width height)};
    die "must supply width and height" unless $max_w && $max_h;

    my ($w, $h, $scenes) = split ' ', `identify -format '\%w \%h \%n' $img`;

    die "Can't resize animated images" unless ($scenes == 1);
    die "Bad dimensions"
        if ($h == 0 || $w == 0 || $max_h == 0 || $max_w == 0);

    # Convert to PNG
    convert($img, "$img.png");
    rename "$img.png", $img or die "Error converting to PNG";

    return if ($w == $max_w && $h == $max_h);

    my @opts = ();

    # aspect ratios (rise over run):
    # tall:   > 1.0
    # square: = 1
    # wide:   < 1.0

    my $ratio         = $h / $w;
    my $is_square     = ($h == $w);
    my $new_ratio     = $max_h / $max_w;
    my $new_is_square = ($max_h == $max_w);

    if ($new_is_square && $is_square) {
        # same aspect ratio, just scale
        push @opts, resize => $max_w.'x'.$max_h;
    }
    else {
        if ($new_ratio > $ratio) {
            # new image is taller
            # make the two the same height
            push @opts, resize => 'x'.$max_h;
        }
        else {
            # new image is wider
            # make the two the same width
            push @opts, resize => $max_w.'x';
        }

        # now that they're the same size in one dimension, take a
        # center-anchored chunk of the correct size
        push @opts, gravity => 'Center';
        push @opts, crop => $max_w.'x'.$max_h.'+0+0';
    }

    convert($img, $img, @opts);
}

sub convert {
    my $in = shift;
    my $out = shift;

    my @opts;
    while (my ($k,$v) = splice(@_,0,2)) {
        push @opts, "-$k", $v;
    }

    backtick('convert', $in, @opts, $out);
}

sub crop_geometry {
    my %p = @_;
    my ($width, $height) = ($p{width}, $p{height});
    my ($max_width, $max_height) = ($p{max_width}, $p{max_height});

    my %geometry = (
        width => $width, height => $height,
        x => 0, y => 0
    );

    if ($width > $max_width && $height <= $max_height) {
        $geometry{width}  = $max_width;
        $geometry{height} = $height;
        $geometry{x}      = ($width - $max_width) / 2;
        $geometry{y}      = 0;
    }
    elsif ($height > $max_height && $width <= $max_width) {
        $geometry{width}  = $width;
        $geometry{height} = $max_height;
        $geometry{x}      = 0;
        $geometry{y}      = ($height - $max_height) / 2;
    }

    return %geometry;
}

sub get_proportions {
    my %p = @_;

    my ($width,$height) = (0,0);
    my $ratio = 1;

    if ($p{new_width} and $p{new_height}) {
        ($width,$height) = shrink($p{new_width}, $p{new_height},
                                  $p{max_width}, $p{max_height});
    }
    elsif ($p{new_width}) {
        $ratio = $p{img_width} / $p{img_height};
        $width = $p{new_width};
        $height = $width / $ratio;
        ($width,$height) = shrink($width,$height,$p{max_width},$p{max_height});
    }
    elsif ($p{new_height}) {
        $ratio = $p{img_width} / $p{img_height};
        $height = $p{new_height};
        $width = $height * $ratio;
        ($width,$height) = shrink($width,$height,$p{max_width},$p{max_height});
    }
    else {
        ($width,$height) = shrink($p{img_width}, $p{img_height},
                                  $p{max_width}, $p{max_height});
    }

    return ($width,$height);
}

1;
