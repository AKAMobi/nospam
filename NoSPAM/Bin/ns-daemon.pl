#!/usr/bin/perl 
use AKA::Mail;


close ( STDERR );
open (STDERR, ">/dev/null");

close ( STDOUT );
open (STDOUT, ">/dev/null");

my $AM = new AKA::Mail;

$AM->server;

