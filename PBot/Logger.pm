# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

package PBot::Logger;

use warnings;
use strict;

use feature 'unicode_strings';

use File::Basename;
use Carp ();

sub new {
  if (ref($_[1]) eq 'HASH') {
    Carp::croak("Options to Logger should be key/value pairs, not hash reference");
  }

  my ($class, %conf) = @_;

  my $logfile = delete $conf{filename};

  if (defined $logfile) {
    my $path = dirname $logfile;
    if (not -d $path) {
      print "Creating new logfile path: $path\n";
      mkdir $path or Carp::croak "Couldn't create logfile path: $!\n";
    }

    open LOGFILE, ">>$logfile" or Carp::croak "Couldn't open logfile $logfile: $!\n";
    LOGFILE->autoflush(1);
  }

  my $self = {
    logfile => $logfile,
  };

  bless $self, $class;
  return $self;
}

sub log {
  my ($self, $text) = @_;
  my $time = localtime;

  $text =~ s/(\P{PosixGraph})/my $ch = $1; if ($ch =~ m{[\s]}) { $ch } else { sprintf "\\x%02X", ord $ch }/ge;

  if (defined $self->{logfile}) {
    print LOGFILE "$time :: $text";
  }

  print "$time :: $text";
}

1;
