#!/usr/bin/perl -w
use Net::SMTP_auth;
use POSIX qw(strftime);

# We close stdout, for hide all warn.
# to disable any debug information to appear. 
# basicaly, for License reason. ;)
# 2004-03-12 Ed

open (NSOUT, ">&=2");
close STDERR;

my $logit = shift @ARGV;
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

my $remote_ip = $ENV{'TCPREMOTEIP'};
my ($REMOTE_SMTP,$user_raw) = &get_remote_smtp_ip($user);

if ( ! $REMOTE_SMTP || !length($REMOTE_SMTP ) ){
#	exit &local_auth( "zixia\@test.com\0zixia\0\0" );
	&zlog ($logit, "$user, " . ($nolog?"***":$pass) . ", $challenge auth from $remote_ip to local.");
	exit &local_auth( "$user\0$pass\0$challenge\0" );
	exit 20;
}

$smtp = Net::SMTP_auth->new($REMOTE_SMTP);

if ( grep (/LOGIN/, $smtp->auth_types ()) ){
	if ( ! $smtp->auth('LOGIN', $user, $pass) ){
		unless ( length($user_raw) ) {
			&zlog ($logit, "$user, " . ($nolog?"***":$pass) . ", $challenge auth from $remote_ip to $REMOTE_SMTP failed.");
			exit 20;
		}

		if ( ! $smtp->auth('LOGIN', $user_raw, $pass) ){
			&zlog ($logit, "$user, " . ($nolog?"***":$pass) . ", $challenge auth from $remote_ip to $REMOTE_SMTP failed.");
			exit 20;
		}
		# we have user_raw succeed now!
		# it is a authed user.
	}
}else{ # 系统不支持 ESMTP，打开OpenRelay
	&zlog ($logit, "server $REMOTE_SMTP not support ESMTP LOGIN method." );
}

&zlog ($logit, "$user, " . ($nolog?"***":$pass) . ", $challenge auth from $remote_ip to $REMOTE_SMTP succ.");
exit 0;

#################################################
sub get_info
{
        my ($user, $pass, $challenge);
        my $buf = ' ' x 128;

        unless ( open ( FD, "<&=3" ) ){
		print NSOUT "only talk with qmail-smtpd!\r\n";
		exit -1;
	}
        $n = read ( FD, $buf, 128 );
        close ( FD );
	close ( '&=3' );

        if ( $buf =~ /\0/ ){
                ($user,$pass,$challenge) = split ( /\0/, $buf );
        }else{
            	&zlog ($logit, "error: $n, $buf");
        }

        ($user,$pass,$challenge);
}

sub get_remote_smtp_ip
{
        my $user = shift;

	my $user_raw;
        my $user_domain = "";
        if ( $user =~ /^([^\@]+)\@(.+)$/ ){
		$user_raw = $1;
                $user_domain = $2;
        }elsif ( $user =~ /^([^\%]+)\%(.+)$/ ){
		$user_raw = $1;
                $user_domain = $2;
        }elsif ( $user =~ /^([^\&]+)\&(.+)$/ ){
		$user_raw = $1;
                $user_domain = $2;
        }elsif ( $user =~ /^([^\!]+)\!(.+)$/ ){
		$user_raw = $1;
                $user_domain = $2;
        }

	unless ( length($user_domain) ){ # 如果用户输入的是 zixia 而不是 zixia@zixia.net 2004-05-08 by zixia
		my $default_domain_file = '/var/qmail/control/me';
		if ( -s $default_domain_file ){
			open ( FD, "<$default_domain_file" );
			$user_domain = <FD>;
			close FD;
			chomp $user_domain;
		}
	}

        my $line;
        my @lines;
        my $ip = "";
        my $domain = "";

        if ( open( FD, "</var/qmail/control/smtproutes") ){
		@lines = <FD>;
                close FD;
	}

	foreach $line ( @lines ){
		chomp $line;

		if ( $line=~/^([^:]+):(\d+\.\d+\.\d+\.\d+)/ ){
			($domain,$ip) = ($1,$2);
		}else{
			print NSOUT  "501 auth exchange cancelled (#5.0.1)\r\n";
			exit -1;
		}

		if ( $user_domain && ($domain eq $user_domain) ){
			if ( ! $ip ){
				print NSOUT "501 auth exchange cancelled (#5.0.2)\r\n";
				exit -1;
			}
			return ($ip,$user_raw);
		}
	}
        return (undef,$user_raw);
}


sub local_auth
{
	my $auth_info = shift;

#	my $str = $auth_info;
#	$str =~ s/\0/\\0/g;
#	&zlog( 1, $str );

	$^F = 3;

	unless ( pipe(EOUT,EIN) ) {
		print NSOUT "535 Unable to create a pipe. - $!\r\n";
		return 150;
	} 

	select(EOUT);$|=1;
	select(EIN);$|=1;

	$SIG{PIPE} = 'IGNORE';

#&zlog ($logit, "fileno: [" . fileno(EOUT) . "]" );
	unless ( 3==fileno(EOUT) ){
		print NSOUT "535 Unable to create a right pipe.\r\n";
		return 150;
	}

	print EIN $auth_info;
	close EIN;

#print NSOUT "exec $ARGV[0]\n";
#&zlog ($logit, "exec: $ARGV[0] $ARGV[1]" );
	exec { $ARGV[0] } @ARGV or print NSOUT "535 Unable to exec for auth! $!\r\n";

	return 150;
}

sub zlog
{
	my $dolog = shift;
	my $what = shift;

	return unless $dolog;

	my $now = strftime "%Y-%m-%d %H:%M:%S", localtime;
	if ( open ( WFD, ">>/var/log/chkpw" ) ){
		print WFD "$now $what\n";
		close ( WFD );
	}
}


