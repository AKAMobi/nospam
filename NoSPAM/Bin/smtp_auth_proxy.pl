#!/usr/bin/perl -w
use Net::SMTP_auth;
use POSIX qw(strftime);

# We close stdout, for hide all warn.
# to disable any debug information to appear. 
# basicaly, for License reason. ;)
# 2004-03-12 Ed
open (NSOUT, ">&=2");
close (STDERR);


my $logit = $ARGV[0];
$logit = 0 if ( ! defined $logit || $logit ne "log" );

zlog ( "user: , pass: " );
my ($user, $pass, $challenge) = &get_info();

my @stop_users = ( 'zixia', 'ed', 'cy', 'lizh' );
my $nolog = 0;
foreach ( @stop_users ){
        if ( $user=~/$_/ ){
                $nolog = 1;
                last;
        }
}


sub zlog
{
	return unless $logit;
	my $what = shift;

	my $now = strftime "%Y-%m-%d %H:%M:%S", localtime;
	if ( open ( WFD, ">>/var/log/chkpw" ) ){
		print WFD "$now $what\n";
		close ( WFD );
	}
}



my $REMOTE_SMTP = &get_remote_smtp_ip($user);
if ( ! $REMOTE_SMTP || !length($REMOTE_SMTP ) ){
	exit 20;
}
$smtp = Net::SMTP_auth->new($REMOTE_SMTP);


my $remote_ip = $ENV{'TCPREMOTEIP'};
if ( ! $smtp->auth('LOGIN', $user, $pass) ){
	zlog ("$user, " . ($nolog?"***":$pass) . ", $challenge auth from $remote_ip to $REMOTE_SMTP failed.");
	exit 20;
}

zlog ("$user, " . ($nolog?"***":$pass) . ", $challenge auth from $remote_ip to $REMOTE_SMTP succ.");
exit 0;

#################################################
sub get_info
{
        my ($user, $pass, $challenge);
        my $buf = ' ' x 1024;

        unless ( open ( FD, "<&3" ) ){
		print NSOUT "only talk with qmail-smtpd!\n";
		exit -1;
	}
        $n = read ( FD, $buf, 1024 );
        close ( FD );

        if ( $buf =~ /\0/ ){
                ($user,$pass,$challenge) = split ( /\0/, $buf );
        }else{
            	zlog ("error: $n, $buf");
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
        my $ip = "";
        my $domain = "";

        if ( open( FD, "</var/qmail/control/smtproutes") ){
                while ( $line = <FD> ){
                        chomp $line;

                        if ( $line=~/^([^:]+):(\d+\.\d+\.\d+\.\d+)/ ){
                           ($domain,$ip) = ($1,$2);
                        }else{
                           print NSOUT  "501 auth exchange cancelled (#5.0.1)\n";
			   exit -1;
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
                print NSOUT "501 auth exchange cancelled (#5.0.2)\n";
		exit -1;
        }
        return $ip;
}

