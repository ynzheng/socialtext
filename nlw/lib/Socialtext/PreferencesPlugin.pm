# @COPYRIGHT@
package Socialtext::PreferencesPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use Class::Field qw( field );
use Socialtext::File;
use Socialtext::JSON qw/decode_json encode_json/;
use Socialtext::SQL qw(:exec :txn);
use Socialtext::Log qw/st_log/;
use Socialtext::Cache;

sub class_id { 'preferences' }
field objects_by_class => {};

sub _cache { Socialtext::Cache->cache('user_workspace_prefs') }

sub load {
    my $self = shift;
    my $values = shift;
    my $prefs = $self->hub->registry->lookup->preference;
    for (sort keys %$prefs) {
        my $array = $prefs->{$_};
        my $class_id = $array->[0];
        my $hash = {@{$array}[1..$#{$array}]}
          or next;
        next unless $hash->{object};
        my $object = $hash->{object}->clone;
        $object->value($values->{$_});
        $object->hub($self->hub);
        push @{$self->objects_by_class->{$class_id}}, $object;
        field($_);
        $self->$_($object);
    }
    return $self;
}

sub new_for_user {
    my $self = shift;
    my $email = shift;

    # This caching does not seem to be well used.
    return $self->{per_user_cache}{$email} if $self->{per_user_cache}{$email};
    my $values = $self->_values_for_email($email);
    return $self->{per_user_cache}{$email} = $self->new_preferences($values);
}

sub _load_all {
    my $self = shift;
    my $email = shift;
    my $wksp  = $self->hub->current_workspace;
    my $cache_key = join ':', $wksp->name, $email;

    my $cache = $self->_cache;
    if (my $prefs = $cache->get($cache_key)) {
        return $prefs;
    }

    my $prefs = $self->_values_for_email_from_db($email)
                || $self->_values_for_email_from_disk($email);
    $cache->set($cache_key => $prefs);
    return $prefs;
}


sub _values_for_email {
    my $self = shift;
    my $email = shift;

    my $prefs = $self->_load_all($email);
    return +{ map %$_, values %$prefs };
}

sub _values_for_email_from_db {
    my $self = shift;
    my $email = shift;

    my $user = Socialtext::User->new(email_address => $email);
    return {} unless $user;

    return $self->Prefs_for_user($user, $self->hub->current_workspace);
}

sub Prefs_for_user {
    my $class_or_self = shift;
    my $user          = shift;
    my $workspace     = shift or die "workspace required";
    my $workspace_id  = $workspace->workspace_id;
    my $email         = $user->email_address;

    my $sth = sql_execute('
        SELECT pref_blob
          FROM user_workspace_pref
         WHERE user_id = ?
           AND workspace_id = ?
       ', $user->user_id, $workspace_id,
    );
    return if $sth->rows == 0;
    my $result = {};
    {
        local $@;
        $result = eval { decode_json($sth->fetchrow_array()); };
        st_log->error(
            "failed to load prefs blob '${email}:$workspace_id': $@"
        ) if $@;
    }
    return $result;
}


# XXX DELETE _values_for_email_from_disk AFTER 2009-05-22 has been released to appliances.
# XXX See https://www2.socialtext.net/dev-tasks/?story_store_user_prefs_in_db
sub _values_for_email_from_disk {
    my $self = shift;
    my $email = shift;

    my $file = Socialtext::File::catfile(
       $self->user_plugin_directory(
           $email, 'do not create the directory for me'
       ),
       'preferences.dd'
    );

    return {} unless -f $file and -r _;

    my $dump = Socialtext::File::get_contents($file);
    return {} unless defined $dump and length $dump;

    my $prefs = eval $dump;
    die $@ if $@;
    return $prefs;
}

sub new_preferences {
    my $self = shift;
    my $values = shift;
    my $new = bless {}, ref $self;
    $new->hub($self->hub);
    $new->load($values);
    return $new;
}

sub new_preference {
    my $self = shift;
    Socialtext::Preference->new(@_);
}

sub new_dynamic_preference {
    my $self = shift;
    Socialtext::Preference::Dynamic->new(@_);
}

sub store {
    my $self = shift;
    my ($email, $class_id, $new_prefs) = @_;
    my $prefs = $self->_load_all($email);
    $prefs->{$class_id} = $new_prefs if defined $class_id;

    my $user = Socialtext::User->new(email_address => $email);
    return unless $user;
    $self->Store_prefs_for_user($user, $self->hub->current_workspace, $prefs);
}

sub Store_prefs_for_user {
    my $class_or_self = shift;
    my $user          = shift;
    my $workspace     = shift;
    my $prefs         = shift;

    return unless $workspace->real;

    my @keys = ($user->user_id, $workspace->workspace_id);
    my $json = encode_json($prefs);
    sql_begin_work;
    sql_execute('
        DELETE FROM user_workspace_pref 
         WHERE user_id = ? AND workspace_id = ?
         ', @keys,
     );
    sql_execute('
        INSERT INTO user_workspace_pref (user_id, workspace_id, pref_blob) 
        VALUES (?,?,?)
        ', @keys, $json
    );
    sql_commit;

    $class_or_self->_cache->clear();
}

package Socialtext::Preference;

use base 'Socialtext::Base';

use Class::Field qw( field );
use Socialtext::l10n qw/loc/;

field 'id';
field 'name';
field 'description';
field 'query';
field 'type';
field 'choices';
field 'default';
field 'default_for_input';
field 'handler';
field 'owner_id';
field 'size' => 20;
field 'edit';
field 'new_value';
field 'error';
field layout_over_under => 0;

sub new {
    my $class = shift;
    my $owner = shift;
    my $self = bless {}, $class;
    my $id = shift || '';
    $self->id($id);
    my $name = $id;
    $name =~ s/_/ /g;
    $name =~ s/\b(.)/\u$1/g;
    $self->name($name);
    $self->query("$name?");
    $self->type('boolean');
    $self->default(0);
    $self->handler("${id}_handler");
    $self->owner_id($owner->class_id);
    return $self;
}

sub value {
    my $self = shift;
    return $self->{value} = shift
      if @_;
    return defined $self->{value} 
      ? $self->{value}
      : $self->default;
}

sub value_label {
    my $self = shift;
    my $choices = $self->choices
      or return '';
    return ${ {@$choices} }{$self->value} || '';
}
    
sub form_element {
    my $self = shift;
    my $type = $self->type;
    return $self->$type;
}

sub input {
    my $self = shift;
    my $name = $self->owner_id . '__' . $self->id;
    my $value = $self->value ||
      # support lazy eval...
      ( ref($self->default_for_input) eq 'CODE' ? $self->default_for_input->($self) : $self->default_for_input ) ||
      $self->value;
    my $size = $self->size;
    return <<END
<input type="text" name="$name" value="$value" size="$size" />
END
}

sub boolean {
    my $self = shift;
    my $name = $self->owner_id . '__' . $self->id;
    my $value = $self->value;
    my $checked = $value ? 'checked="checked"' : '';
    return <<END
<input type="checkbox" name="$name" value="1" $checked />
<input type="hidden" name="$name-boolean" value="0" $checked />
END
}

sub radio {
    my $self = shift;
    my $i = 1;
    my @choices = map { loc($_) } @{$self->choices};
    my @values = grep {$i++ % 2} @choices;
    my $value = $self->value;

    $self->hub->template->process('preferences_radio.html',
        name => $self->owner_id . '__' . $self->id,
        values => \@values,
        default => $value,
        labels => { @choices },
    );
}

sub pulldown {
    my $self = shift;
    my $i = 1;
    my @choices = map { loc($_) } @{$self->choices};
    my @values = grep {$i++ % 2} @choices;
    my $value = $self->value;
    $self->hub->template->process('preferences_pulldown.html',
        name => $self->owner_id . '__' . $self->id,
        values => \@values,
        default => $value,
        labels => { @choices },
    );
}

sub hidden {
    my $self = shift;
    my $name = $self->owner_id . '__' . $self->id;
    my $value = $self->value;
    return <<END
<input type="hidden" name="$name" value="$value" />
END
}

package Socialtext::Preference::Dynamic;
use base 'Socialtext::Preference';

use Class::Field qw( field );
use Socialtext::l10n qw/loc/;

field 'choices_callback';

sub choices { shift->_generic_callback("choices", @_) }

sub _generic_callback {
    my ($self, $name, @args) = @_;
    my $method = "${name}_callback";
    if ($self->$method) {
        return $self->$method->($self, @args);
    } else {
        $method = "SUPER::${name}";
        return $self->$method(@args);
    }
}

1;
