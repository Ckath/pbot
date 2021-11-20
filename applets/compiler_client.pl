#!/usr/bin/perl

# SPDX-FileCopyrightText: 2021 Pragmatic Software <pragma78@gmail.com>
# SPDX-License-Identifier: MIT

# compiler_client.pl connects to compiler_server.pl hosted at PeerAddr/PeerPort below
# and sends a nick, language and code, then retreives and prints the compilation/execution output.
#
# this way we can run the compiler virtual machine on any remote server.

use warnings;
use strict;

use IO::Socket;
use JSON;

my $sock = IO::Socket::INET->new(
    PeerAddr => '127.0.0.1',
    PeerPort => 9000,
    Proto    => 'tcp'
);

if (not defined $sock) {
    print "Fatal error compiling: $!; try again later\n";
    die $!;
}

my $json = join ' ', @ARGV;
my $h    = decode_json $json;

my $lang = $h->{lang} // "c11";

if ($h->{code} =~ s/-lang=([^ ]+)//) { $lang = lc $1; }

$h->{lang} = $lang;
$json = encode_json $h;

print $sock "$json\n";

while (my $line = <$sock>) { print "$line"; }

close $sock;
