#!/usr/bin/perl -w

use Net::SMTP_auth;
use strict;

my ($user,$pass,$REMOTE_SMTP) = @ARGV;

my $smtp = Net::SMTP_auth->new($REMOTE_SMTP);

use Data::Dumper;
print Dumper($smtp->auth_types ());
print "Result: " . grep (/LOGIN/, $smtp->auth_types ());
exit;

if ( $smtp->auth('LOGIN', $user, $pass) ){
	print "Auth with [$user]:[$pass]\@$REMOTE_SMTP succ!\n";
}else{
	print "Auth with [$user]:[$pass]\@$REMOTE_SMTP fail!\n";
}

exit 0;

