#!/usr/bin/perl -w
use Net::SMTP_auth;

my $logit = $ARGV[0];
$logit = 0 if ( ! defined $logit || $logit ne "log" );

my ($user, $pass, $challenge) = &get_info();

my @stop_users = ( 'zixia', 'ed', 'cy', 'lizh' );
my $nolog = 0;
foreach ( @stop_users ){
	if ( $user=~/$_/ ){
		$nolog = 1;
		last;
	}
}


my $REMOTE_SMTP = &get_remote_smtp_ip($user);
exit 20 if ( ! $REMOTE_SMTP || !length($REMOTE_SMTP ) );

$smtp = Net::SMTP_auth->new($REMOTE_SMTP);

open ( WFD, ">>/var/log/chkpw" ) if ( $logit );

my $now = `date +"%Y-%m-%d %H:%M:%S"`;
chomp $now;

my $remote_ip = $ENV{'TCPREMOTEIP'};
if ( $smtp->auth('LOGIN', $user, $pass) ){
	print WFD "$now $user, " . ($nolog?"***":$pass) . ", $challenge auth from $remote_ip to $REMOTE_SMTP succ.\n" if ( $logit );
        exit 0;
}else{
	print WFD "$now $user, " . ($nolog?"***":$pass) . ", $challenge auth from $remote_ip to $REMOTE_SMTP failed.\n" if ( $logit );
}
close ( WFD ) if ( $logit );

exit 20;

sub get_info
{
	my ($user, $pass, $challenge);
	my $buf = ' ' x 1024;

	open ( FD, "<&3" ) or die "only talk with qmail-smtpd!\n";
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

sub get_remote_smtp_ip
{
	my $user = shift;

	my $user_domain = "";
	if ( $user =~ /^[^\@]+\@(.+)$/ ){
		$user_domain = $1;
	}

	my $line;
	my $ip = "";
	my $domain = "";

	if ( open( FD, "</var/qmail/control/smtproutes") ){
		while ( $line = <FD> ){
			chomp $line;

			if ( $line=~/^([^:]+):(\d+\.\d+\.\d+\.\d+)/ ){
				($domain,$ip) = ($1,$2);
			}else{
				die "501 auth exchange cancelled (#5.0.1)\n";
			}

			if ( !$user_domain ){
				last;
			}
			if ( $domain eq $user_domain ){
				last;
			}
		}
		close FD;
	}

	if ( ! $ip ){
		die "501 auth exchange cancelled (#5.0.2)\n";
	}
	return $ip;
}

