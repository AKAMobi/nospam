#!/usr/bin/perl 
use AKA::Mail;


close ( STDERR );
open (STDERR, ">/var/log/NoSPAM.stderr");

close ( STDOUT );
open (STDOUT, ">/var/log/NoSPAM.stdout");

my $AM = new AKA::Mail;

$AM->server;

