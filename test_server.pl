#!/usr/bin/env perl
use strict;
use warnings;

use English qw( -no_match_vars ) ;
use IO::Socket::INET;
system('./server.pl localhost 20001 60 &') == 0 or die($OS_ERROR);




1;

