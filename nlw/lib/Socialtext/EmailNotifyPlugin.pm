# @COPYRIGHT@
package Socialtext::EmailNotifyPlugin;
use strict;
use warnings;
use base 'Socialtext::Plugin';
use Class::Field qw( const field );
use Socialtext::EmailNotifier;
use Socialtext::l10n qw( loc loc_lang system_locale );

sub class_id { 'email_notify' }
const class_title => loc('Email Notification');
field abstracts => [];
field 'lock_handle';
field notify_requested => 0;

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(preference => $self->notify_frequency);
    $registry->add(preference => $self->sort_order);
    $registry->add(preference => $self->links_only);
}

sub notify_frequency {
    my $self = shift;
    my $p = $self->new_preference('notify_frequency');
    $p->query(loc('How often would you like to receive email updates?'));
    $p->type('pulldown');
    my $choices = [
        0 => loc('Never'),
        1 => loc('Every Minute'),
        5 => loc('Every 5 Minutes'),
        15 => loc('Every 15 Minutes'),
        60 => loc('Every Hour'),
        360 => loc('Every 6 Hours'),
        1440 => loc('Every Day'),
        4320 => loc('Every 3 Days'),
        10080 => loc('Every Week'),
    ];
    $p->choices($choices);
    $p->default(1440);
    return $p;
}

sub sort_order {
    my $self = shift;
    my $p = $self->new_preference('sort_order');
    $p->query(loc('What order would you like the updates to be sorted?'));
    $p->type('radio');
    my $choices = [
        chrono => loc('Chronologically (Oldest First)'),
        reverse => loc('Reverse Chronologically'),
        name => loc('Page Name'),
    ];
    $p->choices($choices);
    $p->default('chrono');
    return $p;
}

sub links_only {
    my $self = shift;
    my $p = $self->new_preference('links_only');
    $p->query(loc('What information about changed pages do you want in email digests?'));
    $p->type('radio');
    my $choices = [
        condensed => loc('Page name and link only'),
        expanded => loc('Page name and link, plus author and date'),
    ];
    $p->choices($choices);
    $p->default('expanded');
    return $p;
}

1;

