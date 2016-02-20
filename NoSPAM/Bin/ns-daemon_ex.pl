#!/usr/bin/perl -w -I/home/NoSPAM

###----------------------------------------###
###     noSPAM server class                ###
###----------------------------------------###
package noSPAM;

use vars qw(@ISA);
use strict;

# I18N
use POSIX qw(setlocale);
use Locale::Messages qw (LC_MESSAGES bind_textdomain_codeset);
use Locale::TextDomain ('engine.nospam.cn');
bind_textdomain_codeset ('engine.nospam.cn' => 'GBK');

use Net::Server::PreFork;
@ISA = qw(Net::Server::PreFork);

use Time::HiRes qw( usleep ualarm gettimeofday tv_interval );
use AKA::Mail;

my $AM = new AKA::Mail;

setlocale (LC_MESSAGES, $AM->get_language());
# Debug 
#print $AM->get_language, "\n";
#my $AL = new AKA::License;
#print $AL->check_expiredate('2004-06-15');
#exit;

### run the server
noSPAM->run(); #	port => '127.0.0.1:40307' 
	   #);
exit;


### set up some server parameters
sub configure_hook {
	my $self = shift;

	#$self->{server}->{port}   = ['127.0.0.1:40307'];
	$self->{server}->{port}   = ['/home/NoSPAM/.ns|SOCK_STREAM|unix'];
#$self->{server}->{chdir}  = '/';      # chdir to root
	$self->{server}->{user}   = 'root'; # user to run as
	$self->{server}->{group}  = 'root'; # group to run as
#$self->{server}->{setsid} = 0;        # daemonize

	$self->{server}->{min_servers} = 2;
	$self->{server}->{max_servers} = 30;

	$self->{server}->{min_spare_servers} = 1;
	$self->{server}->{max_spare_servers} = 2;

	$self->{server}->{max_requests} = 1000;

	$self->{server}->{log_level} = 4;

	$self->{server}->{serialize} = undef; # use default: flock, sem has problem: shm 泄露

	open(STDIN, '</dev/null') || die "Can't close STDIN [$!]";
	open(STDOUT,'>/dev/null') || die "Can't close STDOUT [$!]";
#  	open(STDERR,'>&STDOUT')   || die "Can't close STDERR [$!]";
}


### process the request
sub process_request {
	my $self = shift;

	$AM->{start_time} = [gettimeofday];

	local %ENV = ();

	my ($old_alarm_sig,$old_alarm);

	eval {
		$old_alarm_sig = $SIG{ALRM};
		local $SIG{ALRM} = sub { die "TIMEOUT\n" }; # NB: \n required

		# 5 minute timeout
		# /av/dns/spamassassin(rbl,urirbl,dcc,razor,pyzor etc.)
		$old_alarm = alarm( 300 );
		$AM->net_process_ex;
	}; if ($@) {
		$AM->{zlog}->fatal ( "Mail::net_process_ex call TIMEOUT [$@]" );
		$AM->close_smtp ( 443, "引擎超时", 150 );

		eval {
			local $SIG{ALRM} = sub { die "TIMEOUT\n" }; # NB: \n required
			alarm ( 30 );
			$AM->send_mail_info_ex;
		}; if ($@) {
			$AM->{zlog}->fatal ( "Mail::send_mail_info_ex call TIMEOUT [$@]" );
		}
	}
	$SIG{ALRM} = $old_alarm_sig || 'DEFAULT';
	alarm $old_alarm;

	# 如果配置文件更新，则退出，supervise会重起daemon
	if ( $AM->check_conffile_update() ){
		$self->server_close();
	}
}

sub log_time
{
	'';
}
1;

