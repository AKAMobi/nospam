#!/usr/bin/perl -w 

###----------------------------------------###
###     noSPAM server class                 ###
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
#  open(STDERR,'>&STDOUT')   || die "Can't close STDERR [$!]";
}


### process the request
sub process_request {
	my $self = shift;

	$AM->{start_time} = [gettimeofday];

	local %ENV = ();

	$AM->net_process_ex;

	# 如果配置文件更新，则退出，supervixse会重起daemon
	if ( $AM->check_conffile_update() ){
		$self->server_close();
	}
}

1;

