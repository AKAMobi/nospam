#!/usr/bin/perl -w
use Net::SMTP_auth;

my $REMOTE_SMTP = $ARGV[0];
my $logit = $ARGV[1];
$logit = 0 if ( $logit ne "log" );

my ($user, $pass, $challenge) = &get_info();

my @stop_users = ( 'zixia', 'ed', 'cy', 'lizh' );
my $nolog = 0;
foreach ( @stop_users ){
	if ( $user=~/$_/ ){
		$nolog = 1;
		last;
	}
}

my $remote_ip = $ENV{'TCPREMOTEIP'};

$smtp = Net::SMTP_auth->new($REMOTE_SMTP);

open ( WFD, ">>/var/log/chkpw.log" ) if ( $logit );

my $now = `date +"%Y-%m-%d %H:%M:%S"`;
chomp $now;

if ( $smtp->auth('LOGIN', $user, $pass) ){
	print WFD "$now $user, " . ($nolog?"***":$pass) . ", $challenge auth from $remote_ip succ.\n" if ( $logit );
        exit 0;
}else{
	print WFD "$now $user, " . ($nolog?"***":$pass) . ", $challenge auth from $remote_ip failed.\n" if ( $logit );
}
close ( WFD ) if ( $logit );

exit 20;

sub get_info
{
	my ($user, $pass, $challenge);
	my $buf = ' ' x 1024;

	open ( FD, "<&3" ) or die "only talk with qmail-smtpd!";
	$n = read ( FD, $buf, 1024 );
	close ( FD );

	if ( $buf =~ /\0/ ){
		($user,$pass,$challenge) = split ( /\0/, $buf );
	}else{
		if ( $logit ){
			open ( WFD, ">>/var/log/chkpw.log" );
			print WFD "error: $n, $buf\n";
			close ( WFD );
		}
	}

	($user,$pass,$challenge);
}
