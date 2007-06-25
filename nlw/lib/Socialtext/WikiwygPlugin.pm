# @COPYRIGHT@
package Socialtext::WikiwygPlugin;
use strict;
use warnings;

our $VERSION = '0.10';

use base 'Socialtext::Plugin';

use Class::Field qw( const field);
use Socialtext::Formatter;
use Socialtext::System;
use Socialtext::Helpers;
use File::Path ();
use List::Util;
use Socialtext::File;
use Socialtext::l10n qw( loc );
use Imager;
use Digest::MD5;
use Encode;
use YAML;

sub class_id { 'wikiwyg' }
const cgi_class => 'Socialtext::Wikiwyg::CGI';
const class_title => loc('Page Editing');
field widgets_definition => {} => -init => q{
        my $yaml_path = Socialtext::AppConfig->code_base . '/javascript/Widgets.yaml';
        YAML::LoadFile($yaml_path);
};

my $out_path = '/tmp/wikiwyg-' . $<;
my $test_list_override = "";
$test_list_override = join "\n", qw(
    blockquote_test_3
    blockquote_test_2
    blockquote_test_1
    formatting_test
);

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(action => 'wikiwyg_generate_widget_image');
    $registry->add(action => 'wikiwyg_get_page_html2');
    $registry->add(action => 'wikiwyg_save_validation_result');
    $registry->add(action => 'wikiwyg_wikitext_to_html');
    $registry->add(action => 'wikiwyg_start_test');
    $registry->add(action => 'wikiwyg_get_page_html');
    $registry->add(action => 'wikiwyg_test_results');
    $registry->add(action => 'wikiwyg_test_runner');
    $registry->add(action => 'wikiwyg_all_page_ids');
    $registry->add(action => 'wikiwyg_start_validation');
    $registry->add(preference => $self->wikiwyg_double);
    $registry->add(wafl => wikiwyg_formatting_test =>
                   'Socialtext::Wikiwyg::FormattingTest');
    $registry->add(wafl => wikiwyg_formatting_test_run_all =>
                   'Socialtext::Wikiwyg::FormattingTestRunAll');
    $registry->add(wafl => wikiwyg_data_validator =>
                   'Socialtext::Wikiwyg::DataValidator');
}

sub wikiwyg_generate_widget_image {
    my $self = shift;

    my $text = $self->cgi->widget;

    my $widget_string = $self->cgi->widget_string;
    my $widget_localize_string = $self->cgi->widget_localize_string;
    my $uneditable = $self->widget_is_uneditable($widget_string);

    my $image_file = $self->get_image_file_name($text);
    return $self->do_generate_widget_image($widget_localize_string, $image_file, $uneditable);
}

sub generate_widget_image {
    my $self = shift;
    my $text = shift;

    my $uneditable = $self->widget_is_uneditable($text);

    $text = $self->widget_image_text($text);
    my $image_file = $self->get_image_file_name($text);
    $self->do_generate_widget_image($text, $image_file, $uneditable);
}

sub set_fields {
    my $self = shift;
    my $widget = shift; # [reference/out] widget hash to be updated
    my $args = shift; # [in] arguement string for wafl
    my $widgets = shift; # [in] widgets definition hash

    my $definition = $widgets->{widget}->{$widget->{id}};

    return if (!exists($definition->{fields}) && !exists($definition->{field}));

    if (exists($definition->{fields})) {
        foreach (@{$definition->{fields}}) {
            $widget->{$_} = '' if ($_ ne 'label');
        }
    }
    elsif (exists($definition->{field})) {
        $widget->{$definition->{field}} = '';
    }

    return if ($args !~ /\S/) ;

    if (! (exists($definition->{field}) || exists($definition->{parse}))) {
        $definition->{field} = $definition->{fields}->[0];
    }

    if (exists($definition->{field}) && defined($definition->{field})) {
        $widget->{$definition->{field}} = $args || '';
        return;
    }

    my @fields = exists($definition->{parse}->{fields})
        ? @{$definition->{parse}->{fields}}: @{$definition->{fields}};
    my $regex = $definition->{parse}->{regexp};
    my $regex2 = $definition->{parse}->{regexp};
    $regex2 =~ s/^\?//;
    if ($regex ne $regex2) {
        $regex = $widgets->{regexps}->{$regex2};
    }

    my @tokens = $args =~ /$regex/;
    if (@tokens) {
        foreach my $field (@fields) {
            $widget->{$field} = shift @tokens;
        }
    }
    elsif (exists($definition->{parse}->{no_match})) {
        $widget->{$definition->{parse}->{no_match}} = $args;
    }

    if (exists($widget->{search_term})) {
        my $term = $widget->{search_term};
        $term =~ s/^(tag|category|title)://;
        if ($term eq $widget->{search_term}) {
            $widget->{search_type} = 'text';
        }
        else {
            $widget->{search_type} = $1;
            $widget->{search_term} = $term;
        }
    }
}

sub resolve_synonyms {
    my $this = shift;
    my $wafl_text = shift;
    my $widgets = shift;

    foreach my $key (keys %{$widgets->{synonyms}}) {
        my $match = "^$key";
        my $replace = $widgets->{synonyms}->{$key};
        $wafl_text =~ s/$match/$replace/;
    }

    return $wafl_text;
}

sub is_multiple {
    my $self = shift;
    my $widget_id = shift;
    my $widgets = shift;

    my $regex = $widget_id . "\\d+\$";
    foreach my $key (keys %{$widgets->{widget}}) {
        return 1 if ($key =~ /$regex/);
    }
    return 0;
}

sub get_first_multiple {
    my $self = shift;
    my $widget_id = shift;
    my $widgets = shift;

    my $regex = $widget_id . "\\d+\$";
    foreach my $key (keys %{$widgets->{widget}}) {
        return $key if ($key =~ /$regex/);
    }
    return $widget_id;
}

sub map_multiple_same_widgets {
    my $self = shift;
    my $widget = shift;
    my $widgets = shift;

    my $id = $widget->{id};
    my $stripped_id = $widget->{id};
    $widget->{id} =~ /(.+)\d+$/;
    my $nameMatch = "$1\\d+\$";

    foreach my $name (@{$widgets->{widgets}}) {
        if ($name =~ /$nameMatch/) {
            if (exists($widgets->{widget}->{$name}->{select_if})) {
                my $select_if = $widgets->{widget}->{$name}->{select_if};
                my $match = 1;
                if (exists($select_if->{defined})) {
                    foreach my $field (@{$select_if->{defined}}) {
                        if (! $widget->{$field}) {
                            $match = 0;
                            last;
                        }
                    }
                }

                if (exists($select_if->{blank})) {
                    foreach my $field (@{$select_if->{blank}}) {
                        if ($widget->{$field}) {
                            $match = 0;
                            last;
                        }
                    }
                }

                if ($match) {
                    $id = $name;
                    last;
                }
            }
        }
    }

    return $id;
}

sub parse_widget {
    my $self = shift;
    my $wafl_text = shift;
    my $widgets = shift;

    my $widget = {};
    $widget->{id} = undef;
    $widget->{label} = '';
    $widget->{full} = 0;
    my $args = '';

    my @matches = ();
    if (
        (@matches = $wafl_text =~ /^(aim|yahoo|ymsgr|skype|callme|callto|http|asap|irc|file|ftp|https):([\s\S]*?)\s*$/)
        || (@matches = $wafl_text =~ /^{({(.+)})}$/) # asis
        || (@matches = $wafl_text =~ /^"(.+?)"<(.+?)>$/) # Named Links
        || (@matches = $wafl_text =~ /^(?:"(.*)")?\{(\w+):?\s*([\s\S]*?)\s*\}$/)
        || (@matches = $wafl_text =~ /^\.(\w+)\s*?\n([\s\S]*?)\1\s*?$/)
    ) {
        if (3 == @matches) {
            $widget->{label} = $matches[0];
            $widget->{id} = $matches[1];
            $args = $matches[2];
        }
        else {
            $widget->{id} = $matches[0];
            $args = $matches[1];
        }

        if ( $widget->{id} =~ /^{/) {
            $widget->{id} = 'asis';
        }

        $widget->{id} = $self->resolve_synonyms($widget->{id}, $widgets);

        if ($widget->{id} =~ /^(.*)_full$/) {
            $widget->{id} = $1;
            $widget->{full} = 1;
        }
        # Since multiple versions of the same widget have the same wafl
        # structure we can use the parser for any version. Might as well be the first.
        my $is_multiple = $self->is_multiple($widget->{id}, $widgets);
        if ($is_multiple) {
            $widget->{id} = $self->get_first_multiple($widget->{id}, $widgets);
        }

        $self->set_fields($widget, $args, $widgets);

        if ($is_multiple) {
            my $previous_id = $widget->{id};
            $widget->{id} = $self->map_multiple_same_widgets($widget, $widgets);
        }
    }

    return $widget;
}

sub widget_image_text {
    my $self = shift;
    my $wafl = shift;


    my $text = $wafl;
    my $widget = $self->parse_widget($wafl, $self->widgets_definition);

    my $id = $widget->{id};
    if (defined($id)) {
        if ($wafl =~ /^\.html/) {
            $text = $widget->{html}->{title};
        }
        elsif ($id && $self->widgets_definition->{widget}->{$id}->{image_text}) {
            foreach my $condition (@{$self->widgets_definition->{widget}->{$id}->{image_text}}) {
                if ($condition->{field} eq 'default') {
                    $text = $condition->{text};
                    last;
                }
                elsif ($widget->{$condition->{field}}) {
                    $text = $condition->{text};
                    last;
                }
            }
        }

        my @tokens = $text =~ /%(\w+)/g;
        foreach my $token (@tokens) {
            if (exists($widget->{$token})) {
                my $match = '%' . $token;
                $text =~ s/$match/$widget->{$token}/;
            }
        }
    }

    return $text;
}


sub generate_phrase_widget_image {
    my $self = shift;
    my $text = shift;

    $text =~ s/-=/-/g;

    my $uneditable = $self->widget_is_uneditable($text);
    $text = $self->widget_image_text($text);

    my $image_file = $self->get_image_file_name($text);
    $self->do_generate_widget_image($text, $image_file, $uneditable);
}

sub generate_block_widget_image {
    my $self = shift;
    my $widget = shift;

    my $method = $widget->method;
    my $yaml = $self->widgets_definition;

    my $text = exists($yaml->{widget}{$method}) ?
        $yaml->{widget}{$method}{title} :
        'unknown';

    my $image_file = $self->get_image_file_name($text);
    $self->do_generate_widget_image($text, $image_file);
}

sub widget_is_uneditable {
    my $self = shift;
    my $text = shift;

    my $widget = $self->parse_widget( $text, $self->widgets_definition );

    # Uneditable = Defined to be uneditable, or not defined to be a widget.
    return 1
        unless defined( $widget->{id} )
        && defined $self->widgets_definition->{widget}{ $widget->{id} };
    return $self->widgets_definition->{widget}{ $widget->{id} }{uneditable};
}

my @font_table = grep {
    -f Socialtext::AppConfig->code_base . '/fonts/' . $_->{font}
} YAML::LoadFile(
    Socialtext::AppConfig->code_base . '/fonts/config.yaml'
);
die "Invalid font table in 'fonts/config.yaml'"
    unless @font_table and $font_table[0]->{default};
unshift @font_table, 'dummy first entry';

my $font_path = Socialtext::AppConfig->code_base .  '/fonts';
my $widgets_path = Socialtext::AppConfig->code_base . '/images/widgets';
my $max = 300;
#my $height = 18;
my $height = 19;
my $ellipsis = '...';

sub get_image_file_name {
    my $self = shift;
    my $text = shift;
    Encode::_utf8_off($text);
    my $file_name = Digest::MD5::md5_hex($text) . '.png';
    my $image_file = "$widgets_path/$file_name";
    Encode::_utf8_on($text);

    return $image_file;
}

sub do_generate_widget_image {
    my $self = shift;
    my $text = shift;
    my $image_file = shift;
    my $uneditable = shift;
    my $current = 0;

#    Encode::_utf8_off($text);
#    my $file_name = Digest::MD5::md5_hex($text) . '.png';
#    my $image_file = "$widgets_path/$file_name";

    return if -f $image_file;
#    Encode::_utf8_on($text);

    my @texts;
    my $text_num = 0;
    $texts[$text_num] = {str => '', type => 0};
    for my $char (split //, $text) {
        my $ord = ord($char);
        if ($current) {
            my $entry = $font_table[$current];
            if ($ord >= $entry->{lower} and
                $ord <= $entry->{upper}) {
                $texts[$text_num]{str} .= $char;
                next;
            }
        }
        my $font_type = 0;
        for (my $i = 1; $i < @font_table; $i++) {
            if ($ord >= $font_table[$i]{lower} and
                $ord <= $font_table[$i]{upper}) {
                $font_type = $i;
                last;
            }
        }
        unless ($font_type) {
            $char = '?';
            $font_type = 1;
        }
        unless ($texts[$text_num]{type}) {
            $texts[$text_num]{type} = $font_type;
        }
        if ($texts[$text_num]{type} == $font_type) {
            $texts[$text_num]{str} .= $char;
            next;
        }
        $texts[++$text_num] = {str => $char, type => $font_type};
    }

    my %fonts;

    my $x = 4;
    my $overflow = 0;
    for my $text (@texts) {
        my $type = $text->{type};
        my $str = $text->{str};
        $text->{x} = $x;
        my $font = $fonts{$type} ||= $self->new_font($type);
        my ($neg, $xxx, $pos) = $font->bounding_box(string => $str);
        $x += $pos - $neg;
        if ($x >= $max) {
            $font = $fonts{1} ||= $self->new_font(1);
            my ($neg, $xxx, $pos) = $font->bounding_box(string => $ellipsis);
            $overflow = $pos - $neg;
            last;
        }
    }
    $x += 4;

    my $width = $x > $max ? $max : $x;
    $width+=2;

    my $image = Imager->new(xsize => $width, ysize => $height, channels => 4);

    my $background_color = $uneditable ? Imager::Color->new(238,238,238) : Imager::Color->new(255, 251, 248);
    my $font_color = Imager::Color->new( 85,85,85 );
    my @boundary_points = (
        [3,0], [$width-4,0],
        [$width-1,3], [$width-1,$height-3],
        [$width-4,$height-1], [3,$height-1],
        [0,$height-3], [0,3], [3,0]
    );
    $image->polygon(
        points => \@boundary_points,
        color => $background_color
    );

    $image->polyline(
        points => \@boundary_points,
        color => Imager::Color->new( 17, 12, 201),
        aa => 1,
    );

    for my $text (@texts) {
        last unless $text->{x};
        my $font = $fonts{$text->{type}};
        $font->align(
            string => $text->{str},
            color => $font_color,
            x => $text->{x},
            y => int($height / 2) + 1,
            halign => 'left',
            valign => 'center',
            image => $image,
        );
    }
    if ($overflow) {
        my $font = $fonts{1};
        my @overflow_boundary_points = (
            [$width - $overflow - 8,2], [$width-4,2],
            [$width-1,4], [$width-1,$height-4],
            [$width - $overflow - 8,$height-3]
        );

        $image->polygon(
            points => \@overflow_boundary_points,
            color => $background_color
        );

        $font->align(
            string => $ellipsis,
            color => $font_color,
            x => $max - $overflow - 2,
            y => int($height / 2) + 1,
            halign => 'left',
            valign => 'center',
            image => $image,
        );
    }

    $image->write(
        file => $image_file,
    ) or die "Cannot save $image_file ", $image->errstr;
}

sub new_font {
    my $self = shift;
    my $type = shift;

    return Imager::Font->new(
        file => $font_path . '/' . $font_table[$type]{font},
        size => $font_table[$type]{size},
        utf8 => 1,
    ) or die "Cannot load $font_path ", Imager->errstr;
}

sub wikiwyg_get_page_html2 {
    my $self = shift;
    my $page_id = $self->cgi->page_id;
    my $session_id = $self->cgi->session_id;

    # If the page id is null or empty throw a DataValidation Error
    unless ( defined $page_id && length $page_id ) {
        Socialtext::Exception::DataValidation->throw(
            errors => [loc('No page ID given')] );
    }

    # Get all the page ids for comparison against the inputted page id
    my @page_ids = sort$self->hub->pages->all_ids;

    # If the page id does not exist throw a DataValidation Error
    unless ( grep (/^$page_id$/,@page_ids)) {
        Socialtext::Exception::DataValidation->throw(
            errors => [loc("An invalid page ID was given: [_1]", $page_id)] );
    }

    if (! -d "/tmp/wikiwyg_data_validation/$session_id") {
        Socialtext::Exception::DataValidation->throw(
          errors => [loc('Validation subroutine called outside of validator')] );
    }

    my $wikitext = $self->hub->pages->new_from_name($page_id)->content;
    my $html = $self->hub->viewer->text_to_html($wikitext);
    Socialtext::File::set_contents(
        "/tmp/wikiwyg_data_validation/$session_id/old/$page_id", $wikitext );

    return $html;
}

sub wikiwyg_save_validation_result {
    my $self = shift;
    my $wikitext = $self->cgi->content;
    my $page_id = $self->cgi->page_id;
    my $session_id = $self->cgi->session_id;
    Socialtext::File::set_contents(
        "/tmp/wikiwyg_data_validation/$session_id/new/$page_id", $wikitext );

    return "finished\n";
}

sub wikiwyg_start_validation {
    my $self = shift;
    my $session_id = time;
    mkdir("/tmp/wikiwyg_data_validation");
    mkdir("/tmp/wikiwyg_data_validation/$session_id");
    mkdir("/tmp/wikiwyg_data_validation/$session_id/old");
    mkdir("/tmp/wikiwyg_data_validation/$session_id/new");
    return $session_id;
}

sub wikiwyg_all_page_ids {
    my $self = shift;
    join("\n",$self->hub->pages->all_ids_newest_first);
}

sub power_user {
    my $self = shift;
    my $username = $self->hub->current_user->username;
    return ($username =~ /\@socialtext.com$/ and
            $username !~ /(
            ross |
            adina |
            matthew\.mahoney |
            billybob\.hambone
            )/xi) ? 1 : 0;
}

sub wikiwyg_double {
    my $self = shift;
    my $p = $self->new_preference('wikiwyg_double');
    $p->query(loc('Double-click to edit a page?'));
    $p->default(1);
    return $p;
}

sub wikiwyg_test_runner {
    my $self = shift;
    return $self->render_screen(
        output => <<"..."
<script>
Wikiwyg.get_live_update( 'index.cgi',
                         'action=wikiwyg_start_test',
                         test_each_page);
</script>
<h1>Wikitext->HTML->Wikitext Roundtrip Testing in Progress...</h1>
<div id='wikiwyg_info'>
</div>
...
    );
}

sub wikiwyg_test_results {
    my $self = shift;
    my $diff_options = shift || '-u';
    my $page_id = $self->cgi->page_id;
    my $output = Socialtext::System::backtick(
        'diff', $diff_options,
        "$out_path/original/$page_id",
        "$out_path/tested/$page_id"
    );
    $output = $self->html_escape($output);
    my $html = Socialtext::System::backtick('cat', "$out_path/html/$page_id");
    $html = $self->html_escape($html);

    my $return = "<h3>$page_id</h3>\n";
    if ($output =~ /\S/) {
        $return .= "<h4>Differences in roundtrip:</h4><br/><pre>\n$output\n\n$html</pre>\n";
    }
    else {
        $return .= "All wikitext roundtripped exactly.<br/>\n";
    }
    return $return;
}

sub wikiwyg_wikitext_to_html {
    my $self = shift;
    my $wikitext = $self->cgi->content;
    my $html = $self->hub->viewer->text_to_html($wikitext);
    return $self->html_formatting_hack($html);
}

sub html_formatting_hack {
    my $self = shift;
    my $html = shift;
    $html =~ s!</div>\s*\z!<br/></div>\n!;

    # XXX - IE Workaround
    # An empty wafl (e.g. {image:} ) generates HTML like:
    # <div class="wiki"><span class="nlw_phrase"><span class="wafl_syntax_error"></span><!-- wiki: {image} --></span><br/></br/></div>
    # Turns out that if the span before the comment is empty IE will remove the
    # comment when the HTML is assigned using innerHTML inside wikiwyg. By putting a
    # forced space IE does not remove the comment and all is well. I tried just a plain old
    # space but IE removed that as well.
    $html =~ s!wafl_syntax_error"><\/span>!wafl_syntax_error">&nbsp;<\/span>!g;
#    $html =~ s!wafl_syntax_error><\/span>!wafl_syntax_error>&nbsp;<\/span>!g;
    return $html;
}

sub wikiwyg_start_test {
    my $self = shift;
    File::Path::rmtree( $out_path, 0, 1 )
        or die $!;
    return $test_list_override if $test_list_override;
    my @pages = List::Util::shuffle($self->hub->pages->all_ids);
    return "formatting_test\n" . join("\n", @pages[0 .. 10]);
}

sub wikiwyg_get_page_html {
    my $self = shift;
    my $page_id = $self->cgi->page_id;

    # If the page id is null or empty throw a DataValidation Error
    unless ( defined $page_id && length $page_id ) {
        Socialtext::Exception::DataValidation->throw(
            errors => [loc('No page ID given')] );
    }

    # Get all the page ids for comparison against the inputted page id
    my @page_ids = sort$self->hub->pages->all_ids;

    # If the page id does not exist throw a DataValidation Error
    unless ( grep (/^$page_id$/,@page_ids)) {
        Socialtext::Exception::DataValidation->throw(
            errors => [loc("An invalid page ID was given: [_1]", $page_id)] );
    }

    my $wikitext = $self->hub->pages->new_from_name($page_id)->content;
    my $html = $self->hub->viewer->text_to_html($wikitext);

    for my $dir ( "$out_path/original", "$out_path/html" ) {
        Socialtext::File::ensure_directory($dir);
    }

    Socialtext::File::set_contents( "$out_path/original/$page_id", $wikitext );
    Socialtext::File::set_contents( "$out_path/html/$page_id" );

    return $html;
}

package Socialtext::Wikiwyg::DataValidator;

use base 'Socialtext::Formatter::WaflPhrase';

sub html {
    my $self = shift;
    qq"
<script>
push_onload_function(
    function() {
        var dv = new Wikiwyg.DataValidator();
        dv.setup('wikiwyg_data_validator');
    }
);
</script>
<div id='wikiwyg_data_validator'>&nbsp;</div>
    ";
}

package Socialtext::Wikiwyg::FormattingTestRunAll;

use base 'Socialtext::Formatter::WaflPhrase';

sub html {
    my $self = shift;
    qq{
        <span id="wikiwyg_test_results">Test Results: </span>
        <script>push_onload_function(Wikiwyg.run_formatting_tests)</script>
    };
}

package Socialtext::Wikiwyg::FormattingTest;

use base 'Socialtext::Formatter::WaflBlock';

my $count = 1;

sub html {
    my $self = shift;
    my $body = $self->block_text;
    my ($html, $wikitext) = split /^~+\s*$/m, $body, 2;
    my $id = 'wikitest_' . $count++;
    my $output =  <<"...";
<div id="$id" class="wikiwyg_formatting_test" style="background-color:#ddd">
Input: <pre style="background-color: transparent">$html</pre>
<hr />
Expected: <pre style="background-color: transparent">$wikitext</pre>
</div>
...
    # XXX smelly. it should probably match better
    # don't traverse units
    $self->units([]);
    return $output;
}

package Socialtext::Wikiwyg::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'content' => '-newlines';
cgi 'page_id';
cgi 'session_id';
cgi 'widget';
cgi 'widget_string';
cgi 'widget_localize_string';

1;
