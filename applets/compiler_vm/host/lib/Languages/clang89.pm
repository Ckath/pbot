#!/usr/bin/perl

# SPDX-FileCopyrightText: 2021 Pragmatic Software <pragma78@gmail.com>
# SPDX-License-Identifier: MIT

use warnings;
use strict;

package Languages::clang89;
use parent 'Languages::_c_base';

sub initialize {
  my ($self, %conf) = @_;

  $self->{sourcefile}      = 'prog.c';
  $self->{execfile}        = 'prog';
  $self->{default_options} = '-Wextra -Wall -Wno-unused -pedantic -Wfloat-equal -Wshadow -std=c89 -lm -Wfatal-errors -fsanitize=integer,undefined,alignment';
  $self->{options_paste}   = '-fcaret-diagnostics';
  $self->{options_nopaste} = '-fno-caret-diagnostics';
  $self->{cmdline}         = 'clang -gdwarf-2 -g3 $sourcefile $options -o $execfile';

  $self->{prelude} = <<'END';
#define _XOPEN_SOURCE 9001
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <math.h>
#include <limits.h>
#include <sys/types.h>
#include <stdint.h>
#include <errno.h>
#include <ctype.h>
#include <assert.h>
#include <locale.h>
#include <setjmp.h>
#include <signal.h>
#include <time.h>
#include <stdarg.h>
#include <stddef.h>
#include <prelude.h>

END
}

1;
