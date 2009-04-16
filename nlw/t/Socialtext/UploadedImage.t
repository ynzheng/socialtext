#!perl
# @COPYRIGHT@
use warnings;
use strict;

use Test::More tests => 50;
use Test::Exception;
use File::Temp qw/tempdir/;
use File::Slurp qw/slurp/;
use mocked 'Socialtext::SQL', ':test';

BEGIN {
    use_ok 'Socialtext::UploadedImage';
}

saving: {
    local $Socialtext::SQL::Mock_in_transaction = 0;

    my $ui = Socialtext::UploadedImage->new(
        table => 'sometable',
        column => 'large_image',
        id => [one_id => 111, two_id => 222],
    );
    isa_ok $ui, 'Socialtext::UploadedImage', 'got img object';
    ok !$ui->has_image_ref;
    dies_ok { $ui->save() } 'not saved; no image_ref';
    ok !$ui->has_image_ref;
    ok_no_more_sql();

    sql_mock_result(undef); # SELECT FOR UPDATE: no rows
    sql_mock_row_count(1); # INSERT

    $ui->image_ref(\"dummy image");
    ok $ui->has_image_ref;
    lives_ok { $ui->save() } 'saved';

    sql_ok(
        name => 'locks rows for update',
        sql => qr/SELECT 1 FROM sometable WHERE one_id = \? AND two_id = \? FOR UPDATE/,
        args => [[111,222]],
    );
    sql_ok(
        name => 'insert the image',
        sql => qr/INSERT INTO sometable \(large_image, one_id, two_id\)/,
        args => [['dummy image',{pg_type=>17}], [111,undef], [222,undef],[]],
    );

    ok_no_more_sql();
}

update_image: {
    local $Socialtext::SQL::Mock_in_transaction = 1;

    my $ui = Socialtext::UploadedImage->new(
        table => 'sometable',
        column => 'small_image',
        id => [two_id => 222, one_id => 111],
        image_ref => \"small dummy image",
    );

    sql_mock_result([1]); # SELECT FOR UPDATE: one row
    sql_mock_row_count(1); # UPDATE
    lives_ok { $ui->save() } 'save for update';

    sql_ok(
        name => 'locks rows for update',
        sql => qr/SELECT 1 FROM sometable WHERE two_id = \? AND one_id = \? FOR UPDATE/,
        args => [[222,111]],
    );
    sql_ok(
        name => 'update the image',
        sql => qr/UPDATE sometable SET small_image = \? WHERE two_id = \? AND one_id = \?/,
        args => [['small dummy image',{pg_type=>17}], [222,undef], [111,undef],[]],
    );
    ok_no_more_sql();

    odd_failure_on_update: {
        sql_mock_result([1]); # SELECT FOR UPDATE: one row
        sql_mock_row_count('0 but true'); # UPDATE: fails for some odd reason
        dies_ok { $ui->save() } 'checked for updated rows';

        sql_ok(
            name => 'locks rows for update',
            sql => qr/SELECT 1 FROM sometable WHERE two_id = \? AND one_id = \? FOR UPDATE/,
            args => [[222,111]],
        );
        sql_ok(
            name => 'update the image',
            sql => qr/UPDATE sometable SET small_image = \? WHERE two_id = \? AND one_id = \?/,
            args => [['small dummy image',{pg_type=>17}], [222,undef], [111,undef],[]],
        );
        ok_no_more_sql();
    }
}

loading: {
    local $Socialtext::SQL::Mock_in_transaction = 0;
    sql_mock_result(['selected image']); # SELECT sql_singlevalue

    my $ui = Socialtext::UploadedImage->new(
        table => 'my_table',
        column => 'my_logo',
        id => [three_id => 333],
    );
    isa_ok $ui, 'Socialtext::UploadedImage', 'got img object';

    lives_ok { $ui->load() } 'load the image';
    is_deeply $ui->image_ref, \'selected image', "read image from db";

    sql_ok(
        name => 'select image',
        sql => 'SELECT my_logo FROM my_table WHERE three_id = ?',
        args => [333],
    );
    ok_no_more_sql();
}

caching: {
    my $dir = tempdir( CLEANUP => 1 );
    ok -d $dir && -r _ && -w _, 'made tempdir';

    my $ui = Socialtext::UploadedImage->new(
        table => 'm_table',
        column => 'm_logo',
        id => [four_id => 444],
        image_ref => \'how witty',
        file_suffix => '-foo.png',
    );

    my $filename;
    lives_ok { $filename = $ui->cache_to_dir($dir) } 'cached';
    is $filename, "$dir/444-foo.png", 'returned the correct filename';
    ok -f $filename && -r _, 'file exists, readable';
    my $file_contents = slurp($filename);
    is $file_contents, 'how witty';

    overwrite_is_ok: {
        my $filename2;
        lives_ok { $filename2 = $ui->cache_to_dir($dir) } 'overwrote';
        is $filename2, $filename, 'same filename';
    }

    read_only_file: {
        ok system("chmod -w $filename") == 0;
        lives_ok { $ui->cache_to_dir($dir) } 'overwrite read-only';
    }

    read_only_dir: {
        ok unlink $filename;
        ok system("chmod -w $dir") == 0;
        dies_ok { $ui->cache_to_dir($dir) } 'read-only dir';
        ok system("chmod +w $dir") == 0;
    }

    # TODO:
    # given that we supply a set of "alternate" ids
    # when we cache it to a directory
    # files with the alternate ids are hard-linked to the original

    $ui->alternate_ids({four_id => ['four','f@ex/../ample.com']});
    lives_ok { $ui->cache_to_dir($dir) } 'overwrite read-only';

    my @files = slurp_dir($dir);

    is_deeply \@files, ['444-foo.png', 'f@ex%2f..%2fample.com-foo.png', 'four-foo.png'],
        'directory contents look good';

    hard_links: {
        my @expect = (stat $filename)[0,1];
        for my $file (@files) {
            my @actual = (stat "$dir/$file")[0,1];
            is_deeply \@actual, \@expect, "file $file is hard-linked";
        }
    }

    shift @files;
    unlink @files;
    $ui->link_alternate_ids($dir);

    @files = slurp_dir($dir);
    is_deeply \@files, ['444-foo.png', 'f@ex%2f..%2fample.com-foo.png', 'four-foo.png'],
        'directory contents look good after unlinking alts';
}

sub slurp_dir {
    my $dir = shift;
    my $dh;
    opendir $dh, $dir;
    my @files = sort grep !/^\./, readdir $dh;
    closedir $dh;
    return @files;
}
