#!/usr/bin/perl -Tw
use AKA::Mail;

$ENV{'PATH'} = '/bin:/sbin:/usr/bin:/usr/sbin';
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

#close ( STDERR );
#open (STDERR, ">/var/log/NoSPAM.stderr");

#close ( STDOUT );
#open (STDOUT, ">/var/log/NoSPAM.stdout");

my $AM = new AKA::Mail;

$AM->server;

