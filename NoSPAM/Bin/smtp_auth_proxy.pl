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

my $REMOTE_SMTP = &get_remote_smtp_ip($user);

if ( ! $REMOTE_SMTP || !length($REMOTE_SMTP ) ){
#	exit &local_auth( "zixia\@test.com\0zixia\0\0" );
	exit &local_auth( "$user\0$pass\0$challenge\0" );
	exit 20;
}

$smtp = Net::SMTP_auth->new($REMOTE_SMTP);

my $remote_ip = $ENV{'TCPREMOTEIP'};
if ( ! $smtp->auth('LOGIN', $user, $pass) ){
	zlog ($logit, "$user, " . ($nolog?"***":$pass) . ", $challenge auth from $remote_ip to $REMOTE_SMTP failed.");
	exit 20;
}

zlog ($logit, "$user, " . ($nolog?"***":$pass) . ", $challenge auth from $remote_ip to $REMOTE_SMTP succ.");
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
            	zlog ($logit, "error: $n, $buf");
        }

        ($user,$pass,$challenge);
}

sub get_remote_smtp_ip
{
        my $user = shift;

        my $user_domain = "";
        if ( $user =~ /^[^\@]+\@(.+)$/ ){
                $user_domain = $1;
        }elsif ( $user =~ /^[^\%]+\%(.+)$/ ){
                $user_domain = $1;
        }elsif ( $user =~ /^[^\&]+\&(.+)$/ ){
                $user_domain = $1;
        }elsif ( $user =~ /^[^\!]+\!(.+)$/ ){
                $user_domain = $1;
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
			return $ip;
		}
	}
        return undef;
}


sub local_auth
{
	my $auth_info = shift;

#	my $str = $auth_info;
#	$str =~ s/\0/\\0/g;
#	zlog( 1, $str );

	$^F = 3;

	unless ( pipe(EOUT,EIN) ) {
		print NSOUT "535 Unable to create a pipe. - $!\r\n";
		return 150;
	} 

	select(EOUT);$|=1;
	select(EIN);$|=1;

	$SIG{PIPE} = 'IGNORE';

#print NSOUT "fileno: " . fileno(EOUT) . "\n";
	unless ( 3==fileno(EOUT) ){
		print NSOUT "535 Unable to create a right pipe.\r\n";
		return 150;
	}

	print EIN $auth_info;
	close EIN;

#print NSOUT "exec $ARGV[0]\n";
	exec { $ARGV[0] } @ARGV or print NSOUT "535 Unable to exec for auth! $!\r\n";

	exit 150;
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


