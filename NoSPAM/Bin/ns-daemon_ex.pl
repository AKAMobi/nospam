#!/usr/bin/perl -w 

###----------------------------------------###
###     noSPAM server class                ###
###----------------------------------------###
package noSPAM;

use vars qw(@ISA);
use strict;

use Net::Server::PreFork;
@ISA = qw(Net::Server::PreFork);

use Time::HiRes qw( usleep ualarm gettimeofday tv_interval );
use AKA::Mail;

my $AM = new AKA::Mail;

### run the server
noSPAM->run(); #	port => '127.0.0.1:40307' 
	   #);
exit;


### set up some server parameters
sub configure_hook {
	my $self = shift;

	$self->{server}->{port}   = ['127.0.0.1:40307'];
#$self->{server}->{chdir}  = '/';      # chdir to root
	$self->{server}->{user}   = 'root'; # user to run as
	$self->{server}->{group}  = 'root'; # group to run as
#$self->{server}->{setsid} = 0;        # daemonize

	$self->{server}->{min_servers} = 2;
	$self->{server}->{max_servers} = 50;

	$self->{server}->{min_spare_servers} = 2;
	$self->{server}->{max_spare_servers} = 10;

	$self->{server}->{max_requests} = 10;

	$self->{server}->{log_level} = 4;

	$self->{server}->{serialize} = 'semaphore';

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

		# 2 minute timeout
		$old_alarm = alarm( 120 );

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
	$SIG{ALRM} = $old_alarm_sig || 'IGNORE';
	alarm $old_alarm;

	# 如果配置文件更新，则退出，supervixse会重起daemon
	if ( $AM->check_conffile_update() ){
		$self->server_close();
	}
}

1;

