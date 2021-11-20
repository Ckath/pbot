# File: UrlTitles.pm
#
# Purpose: Display titles of URLs in channel messages.

# SPDX-FileCopyrightText: 2021 Pragmatic Software <pragma78@gmail.com>
# SPDX-License-Identifier: MIT

package PBot::Plugin::UrlTitles;
use parent 'PBot::Plugin::Base';

use PBot::Imports;

sub initialize {
    my ($self, %conf) = @_;
    $self->{pbot}->{registry}->add_default('text',  'general', 'show_url_titles',                 $conf{show_url_titles}                 // 1);
    $self->{pbot}->{registry}->add_default('array', 'general', 'show_url_titles_channels',        $conf{show_url_titles_channels}        // '.*');
    $self->{pbot}->{registry}->add_default('array', 'general', 'show_url_titles_ignore_channels', $conf{show_url_titles_ignore_channels} // 'none');

    $self->{pbot}->{event_dispatcher}->register_handler('irc.public',  sub { $self->show_url_titles(@_) });
    $self->{pbot}->{event_dispatcher}->register_handler('irc.caction', sub { $self->show_url_titles(@_) });
}

sub unload {
    my ($self) = @_;
    $self->{pbot}->{event_dispatcher}->remove_handler('irc.public');
    $self->{pbot}->{event_dispatcher}->remove_handler('irc.caction');
}

sub show_url_titles {
    my ($self, $event_type, $event) = @_;
    my $channel = $event->{event}->{to}[0];
    my ($nick, $user, $host) = ($event->{event}->nick, $event->{event}->user, $event->{event}->host);
    my $msg = $event->{event}->{args}[0];

    return 0 if not $msg =~ m/https?:\/\/[^\s]/;
    return 0 if $event->{interpreted};

    if ($self->{pbot}->{ignorelist}->is_ignored($channel, "$nick!$user\@$host")) {
        return 0;
    }

    # no titles for unidentified users in +z channels
    my $chanmodes = $self->{pbot}->{channels}->get_meta($channel, 'MODE');
    if (defined $chanmodes and $chanmodes =~ m/z/) {
        my $account  = $self->{pbot}->{messagehistory}->{database}->get_message_account($nick, $user, $host);
        my $nickserv = $self->{pbot}->{messagehistory}->{database}->get_current_nickserv_account($account);
        return 0 if not defined $nickserv or not length $nickserv;
    }

    if (    $self->{pbot}->{registry}->get_value('general', 'show_url_titles')
        and not $self->{pbot}->{registry}->get_value($channel, 'no_url_titles')
        and not grep { $channel =~ /$_/i } $self->{pbot}->{registry}->get_value('general', 'show_url_titles_ignore_channels')
        and grep     { $channel =~ /$_/i } $self->{pbot}->{registry}->get_value('general', 'show_url_titles_channels'))
    {
        my $count = 0;
        while ($msg =~ s/(https?:\/\/[^\s]+)//i && ++$count <= 3) {
            my $url = $1;

            if ($self->{pbot}->{antispam}->is_spam('url', $url)) {
                $self->{pbot}->{logger}->log("Ignoring spam URL $url\n");
                next;
            }

            my $context = {
                from               => $channel,
                nick               => $nick,
                user               => $user,
                host               => $host,
                hostmask           => "$nick!$user\@$host",
                command            => "title $nick $url",
                root_channel       => $channel,
                root_keyword       => "title",
                keyword            => "title",
                arguments          => "$nick $url",
                suppress_no_output => 1,
            };

            $self->{pbot}->{applets}->execute_applet($context);
        }
    }
    return 0;
}

1;
