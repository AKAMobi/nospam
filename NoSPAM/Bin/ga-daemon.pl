#!/usr/bin/perl -w
use AKA::Mail::GA;
use AKA::Mail::GA::GAISC;

$ENV{'PATH'} = '/bin:/sbin:/usr/bin:/usr/sbin';
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

close ( STDERR );
open (STDERR, ">>/var/log/NoSPAM.stderr");

close ( STDOUT );
open (STDOUT, ">>/var/log/NoSPAM.stdout");

my $GA = new AKA::Mail::GA::GAISC;

$GA->start_daemon_process;

