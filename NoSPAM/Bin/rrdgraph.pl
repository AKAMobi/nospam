#!/usr/bin/perl -w

use strict;
use AKA::Mail::Status;

my $AMS=new AKA::Mail::Status;

open ( FD, "</var/log/NoSPAM.rrdds" ) or print STDERR  "can't open NoSPAM.rrdds\n";
# get data source from stdin, and process;
$AMS->ds2rrd ( \*FD );
close FD;

# empty it.
open ( FD, ">/var/log/NoSPAM.rrdds" );
close FD;

# generate gif picture
$AMS->gen_gif;

