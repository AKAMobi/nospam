#!/usr/bin/perl -w

package AKA::Mail::GA::GAISC;

use strict;

use vars qw(@ISA);
#use AKA::Mail::GA;
@ISA=qw(AKA::Mail::GA);

use AKA::Mail::Conf;
use AKA::Mail::Log;

use Errno;
use POSIX qw(strftime);
use IO::Socket;

use Config::Tiny;
use Net::FTP;

use Data::Dumper;

# GW to GA
use constant CATE_REQ_LINK		=> '0000000001';
use constant CATE_RESP_LINK		=> '0000000099';

use constant CATE_ALTDATA_NOTIFY	=> '0000000002';
use constant CATE_ALTDATA_RESULT	=> '0000000098';

use constant CATE_LOGDATA_NOTIFY	=> '0000000003';
use constant CATE_LOGDATA_RESULT	=> '0000000097';


# GA to GW
use constant CATE_MAILRULE_NOTIFY	=> '0000000096';
use constant CATE_MAILRULE_RESULT	=> '0000000004';

use constant CATE_LOGRULE_NOTIFY	=> '0000000094';
use constant CATE_LOGRULE_RESULT	=> '0000000006';

use constant CATE_PING			=> '0000000095';
use constant CATE_PONG			=> '0000000005';

# AKA Ext TODO
#use constant CATE_UL_ALERT		=> '0000000149';
#use constant CATE_UL_LOG_OK		=> '0000000151';

#use constant CATE_UL_LOG		=> '0000000148';
#use constant CATE_UL_LOG_OK		=> '0000000152';


# Data meaning
use constant DATA_SUCC			=> '0000000001';
use constant DATA_FAIL			=> '0000000002';


sub new
{
	my $class = shift;

	my $self = {};

	bless $self, $class;

	my $parent = shift;

	#$self = $self->SUPER::new($parent);

	$self->init();

	$self->{parent} = $parent;
	$self->{zlog} = $parent->{zlog} || new AKA::Mail::Log($self);
	$self->{conf} = $parent->{conf} || new AKA::Mail::Conf($self);

	$self->{define}->{archivedir} = "/home/vpopmail/domains/localhost.localdomain/archive/Maildir/";
	$self->{define}->{GAISC_conffile} = "/home/NoSPAM/etc/GAISC.conf";
	$self->{GAISC} = $self->get_conf();
	
	$self->init();

	return $self;
}

sub check_match
{
	my $self = shift;
	my $mail_info = shift;

	$self->make_copy( $mail_info );

	my $rule_info = $mail_info->{aka}->{rule_info};
	
	if ( 1==$rule_info->{alarmlevel} ){
		$self->feed_alert( $self->make_alert($mail_info) );
	}
}

sub test
{
	my $self = shift;

	my $result = $self->GAISC_get_ftp_info();
	print "ftp info: \n" . Dumper ( $result );


	$result  = $self->GAISC_get_alt_result( '200007230945560001.alt' );
	print "alt result: $result \n";

	my $socket = $self->_connect_ga;
	$result  = $self->GAISC_get_log_result( '200007230945560001.log' );
	print "log result: $result \n";

	exit;

	$self->GAISC_server();
}

sub get_conf
{
	my $self = shift;

        my $C = Config::Tiny->read( $self->{define}->{GAISC_conffile} );
	return $C->{_};
}

sub _get_action
{
	my $self = shift;

	# XXX ref code with $self?
	return {	(CATE_MAILRULE_NOTIFY)	=> \&GAISC_resp_rule_update,
			(CATE_LOGRULE_NOTIFY)	=> \&GAISC_resp_log_update,
			(CATE_PING)		=> \&GAISC_resp_ping
		}
}

sub isEnabled
{
	my $self = shift;
	return $self->SUPER::isEnabled() && ('GAISC' eq uc $self->{conf}->{config}->{GAInterface}->{GAProtocol});
}


sub start_daemon_process
{
	my $self = shift;

	unless ( $self->isEnabled() ){
		$self->{zlog}->debug ( "GA::GAISC not enabled, use parent sleep processer" );
		return $self->SUPER::start_daemon_process();
	}

	$self->GAISC_get_ftp_info();
	return $self->GAISC_server;
	
}

sub update_rule
{
	# suppress GA compain
	# GAISC update rule is passiveness
}

sub mail_info_to_file
{
	my $self = shift;

	my $mail_info = shift;
	my $type = shift;
	my $sel_str = shift || '111100';

	$type = uc $type;
	unless ( $type eq 'ALT' || $type eq 'LOG' ){
		$self->{zlog}->fatal ( "GA::GAISC::mail_info_to_file got type [$type] err." );
		return undef;
	}

	my $content_map = { 1 => 'from'
				, 2 => 'to'
				, 3 => 'cc'
				, 4 => 'subject'
				, 5 => 'content'
				, 6 => 'atta_content'
			};

	my %selector;

	for ( my $n=1; $n<=length($sel_str); $n++ ){
		if ( 1==substr($sel_str,$n-1,1) ){
			$selector{$content_map->{$n}} = 1;
		}
			
	}

#use Data::Dumper;
#$self->{zlog}->debug ( Dumper($mail_info) );
	my $dirname = { 'ALT' => 'alert', 'LOG' => 'log' };

	#srand $serialno;
        #$serialno = sprintf ( "%04d", int($serialno * 9999) );
        #$serialno = int ( $serialno );

	my $emltime = $self->{zlog}->get_time_stamp;;
	$emltime=$1 if ( $mail_info->{aka}->{emlfilename}=~/(\d{14})/ );

      	my $serialno = 0;
	my $filename;
	do {
		$filename = sprintf ( "%s/%s/%s%04d.%s", '/home/ssh/', $dirname->{$type}
				, $emltime, $serialno,lc($type) );
		$serialno++;
	} while( -e $filename && $serialno<=9999 );

#$self->{zlog}->debug ( "mail_info_to_file: $filename" );

	unless ( open ( FD, ">$filename" ) ){
		$self->{zlog}->fatal ( "GA::GAISC::mail_info_to_file can't write file [$filename]" );
		return undef;
	} 

	print FD "GAISC.$type.Rule=" . $mail_info->{aka}->{rule_info}->{rule_id} . "\r\n"
		if ( uc $type eq 'ALT' );

	print FD "GAISC.$type.Time=". $self->{zlog}->get_time_stamp . "\r\n";

	my $from = $self->get_addr_str_from_mail_str($mail_info->{head}->{from});

	print FD "GAISC.$type.From=";
	if ( defined $selector{'from'} ){
		print FD $from;
	}
	print FD "\r\n";

	my $to = $self->get_addr_str_from_mail_str($mail_info->{head}->{to});
	print FD "GAISC.$type.To=";
	if ( defined $selector{'to'} && $to){
		print FD $to;
	}
	print FD "\r\n";

	print FD "GAISC.$type.Cc=";
	my $cc = $self->get_addr_str_from_mail_str($mail_info->{head}->{cc});
	if ( defined $selector{'cc'} && $cc ){
		print FD $cc;
	}
	print FD "\r\n";

	print FD "GAISC.$type.Subject=";
	if ( defined $selector{'subject'} ){
		print FD $mail_info->{head}->{subject};
	}
	print FD "\r\n";

	my $receive_str = $self->get_received_str($mail_info);
	print FD "GAISC.$type.Received=". $receive_str;
		if ( $receive_str ){
			print FD ";\r\n";
		}else{
			print FD "\r\n";
		}

	print FD "GAISC.$type.Length=" . length($mail_info->{body_text}) . "\r\n";

	print FD "GAISC.$type.Content=\r\n";
	if ( defined $selector{'content'} ){
		print FD $mail_info->{body_text} . "\r\n";
	}else{
		print FD "\r\n";
	}

	print FD "GAISC.$type.SelfLength=" . (-s $mail_info->{aka}->{emlfilename}||0) . "\r\n";

	print FD "GAISC.$type.SelfMai=\r\n";
	if ( defined $selector{'content'} ){
		if ( open ( RFD, '<' . $mail_info->{aka}->{emlfilename} ) ){
			print FD while ( <RFD> );
			close ( RFD );
		}
 		print FD "\r\n";
	}

	my $atta_num = 0;
	my $atta_file;
	foreach $atta_file ( keys %{$mail_info->{body}} ){
		next if ( $mail_info->{body}->{$atta_file}->{nofilename} );
		$atta_num++;
	}
	print FD "GAISC.$type.AttachCount=". $atta_num . "\r\n";

	$atta_num = 0;
	foreach $atta_file ( keys %{$mail_info->{body}} ){
		next if ( $mail_info->{body}->{$atta_file}->{nofilename} );
		$atta_num++;
		print FD "GAISC.$type.AttachName$atta_num=" 
			. $atta_file . "\r\n";
		print FD "GAISC.$type.AttachType$atta_num="
			. $mail_info->{body}->{$atta_file}->{type} 
				. '/' . $mail_info->{body}->{$atta_file}->{subtype}
			. "\r\n";
		print FD "GAISC.$type.AttachLength$atta_num="
			. $mail_info->{body}->{$atta_file}->{size} . "\r\n";

		print FD "GAISC.$type.AttachCount$atta_num=\r\n";
		if ( defined $selector{'atta_content'} ){
			print FD $mail_info->{body}->{$atta_file}->{content} . "\r\n";
		}
	}
	close FD;

	return $filename;
}

sub make_copy
{
	my $self = shift;
	my $mail_info = shift;

	
	my $now = $self->{zlog}->get_time_stamp;
	`cat $mail_info->{aka}->{emlfilename} > /home/ssh/log/$now-$$.eml`;
}


sub make_log
{
	my $self = shift;
	my $mail_info = shift;
	
	return $self->mail_info_to_file( $mail_info, 'LOG', $mail_info->{aka}->{rule_info}->{rule_comment} );
}

sub make_alert
{
	my $self = shift;
	my $mail_info = shift;

	return $self->mail_info_to_file( $mail_info, 'ALT', $mail_info->{aka}->{rule_info}->{rule_comment} );
}


sub feed_log
{
	my $self = shift;

	my @logfiles = @_;

	unless ( @logfiles ){
		$self->{zlog}->fatal ( "GA::GAISC::feed_log got no alert file param" );
		return;
	}

	$self->GAISC_get_log_result ( @logfiles );
	#unlink @logfiles;

}

sub feed_alert
{
	my $self = shift;

	my @alertfiles = @_;

	unless ( @alertfiles ){
		$self->{zlog}->fatal ( "GA::GAISC::feed_alert got no alert file param" );
		return;
	}

	$self->GAISC_get_alt_result ( @alertfiles );
	unlink @alertfiles;
}

sub GAISC_server
{
	my $self = shift;

	my $server = new IO::Socket::INET( LocalAddr => $self->{GAISC}->{LocalIP},
					LocalPort => $self->{GAISC}->{LocalPort},
					Proto => 'tcp',
					Type => SOCK_STREAM,
					ReuseAddr => 1,
					Listen => SOMAXCONN
			) || return $self->{zlog}->fatal( "Could not create INET socket: $! $@\n" );

	$self->{zlog}->log( "GA::GAISC_server start to listen " 
			. $self->{GAISC}->{LocalIP} . ':' 
			. $self->{GAISC}->{LocalPort} );


	use POSIX ":sys_wait_h";

=pod
	my $childnum;
	for ( $childnum=0; $childnum<5; $childnum++ ){
		$pid=fork();
		if ( $pid > 0 ){ # parent
			next if $childnum<5;
			my $kid;
			do {
				$kid = waitpid(-1, WNOHANG);
			} until $kid > 0;
		}elsif ( 0==$pid ){ #child
			last;
		}else{ # error
			print "ERR: fork\n";
		}
	}
=cut
	my $client ;
	my $pid;

	local $SIG{CHLD} = 'IGNORE';

	while ( $client = $server->accept() ){
		#print "I'm the $childnum th child\n";

		if (!$client) {
			# this can happen when interrupted by SIGCHLD on Solaris,
			# perl 5.8.0, and some other platforms with -m.
			if ($! == &Errno::EINTR) {
				next;
			} else {
				sleep 1;
				# daemontools should restart me
				$self->{zlog}->fatal ( "GA::GAISC::server accept failed: $!" );
				die "accept failed: $!\n";
			}
		}

=pod
		$pid = fork();

		if ( $pid > 0 ) { #parent
			close $client;
		}elsif ( 0==$pid ){ # child
			close $server;
=cut
			$client->autoflush(1);

			my($port, $ip) = sockaddr_in($client->peername);
			#my $name = gethostbyaddr($ip, AF_INET);
			$ip = inet_ntoa($ip);
			#$name ||= $ip;
			$self->{zlog}->debug ( "GA::GAISC::server got client from ip: [" . $ip . "]" );

			$self->process_protocol( $client );
			shutdown ($client, 2);
			close $client;
=pod
		}else{ #err
			$self->{zlog}->fatal ( "GA::GAISC::server fork return < 0? [$pid]" );
			die "fork failed: $!\n";
		}
=cut
	}

	$self->{zlog}->fatal ( "GA::GAISC::server accept failed? [$!]" );
	shutdown ($server, 2);
	close $server;
}

sub process_protocol
{
	my $self = shift;

	my $socket = shift;

	my $GAISC = $socket->getline;

	chomp $GAISC;
	$self->{zlog}->debug( "CLNT: $GAISC" );

	#GAISC 000000DZYJ 0987654321 20040417212923 0000000095 DZYJ,21,test,test,E
	my $pkg = $self->_parse_GAISC ( $GAISC );

	my $proto_action = $self->_get_action();

	#$self->{zlog}->debug(  Dumper ( $proto_action ) );
#	$self->{zlog}->debug ( "got GAISC data_cate: [" . $pkg->{data_cate} . "]" );

	if ( defined $proto_action->{$pkg->{data_cate}} ){
		&{$proto_action->{$pkg->{data_cate}}}($self, $socket, $pkg);
	}else{
		$self->{zlog}->fatal( "unknown GAISC data_cate: [" . $pkg->{data_cate} . "]" );
	}

}

sub _parse_GAISC
{
	my $self = shift;

	my $GAISC = shift;

	unless ( $GAISC =~ /^(.{5})(.{10})(.{10})(.{14})(.{10})(.+),E/ ){
		$self->{zlog}->fatal ( "GA::AGISC::_parse_GAISC ERR: $GAISC" );
		return undef;
	}

	my $pkg = {	 data_id => $1,
			sys_id => $2, 
			gw_id => $3,
			timestamp => $4,
			data_cate => $5,
			data => $6
	};

	return $pkg;
}

sub get_timestamp
{
	my $self = shift;

	strftime "%Y%m%d%H%M%S", localtime;
}

sub _connect_ga
{
	my $self = shift;

        my $socket = IO::Socket::INET->new(Proto =>"tcp",
                                Timeout => 10,
                                PeerAddr =>$self->{GAISC}->{ServerIP}, 
                                PeerPort =>$self->{GAISC}->{ServerPort}
                                 ) ;
	unless ( $socket && $socket->connected ){
		$self->{zlog}->fatal( "GA::GAISC connect_ga IP: [" 
			. $self->{GAISC}->{ServerIP} . "] Port: [" 
			. $self->{GAISC}->{ServerPort} . "] failure" );
		sleep 1;
		return undef;
	}

	$socket;
}

sub GAISC_get_ftp_info
{
	my $self = shift;

	my $pkg = { data_cate => CATE_REQ_LINK,
			data => $self->{GAISC}->{LocalIP} . ',' . $self->{GAISC}->{LocalPort} . ','
		};

	$pkg = $self->_make_pkg ( $pkg );

	my $socket = $self->_connect_ga;
	$self->_send_pkg ( $socket, $pkg );
	$pkg = $self->_recv_pkg ( $socket );
	close $socket if $socket;

	return undef unless $pkg->{data} =~ /([^,]+),([^,]+),([^,]+),([^,]+)/ ;

	$self->_update_config( {	FTPDir => $1,
				FTPPort => $2,
				FTPUser => $3,
				FTPPass => $4
		});

	return	{	dir => $1,
			port => $2,
			user => $3,
			pass => $4
		};
}

sub GAISC_get_alt_result
{
	my $self = shift;

	my @alt_files = @_;

	unless ( @alt_files ){
		$self->{zlog}->fatal ( "GA::GAISC::GAISC_get_alt_result get no alt_files" );
		return;
	}

	my $ftp = $self->_connect_ftp();
	my $err = 1 unless $ftp;

	$self->ftp_put_file( $ftp, '/home/ssh/alert',
		'/' . $self->{GAISC}->{FTPDir} . '/alert/' . $self->{GAISC}->{GatewayIdentifier} . '/'
		, @alt_files ) unless $err;

	$ftp->quit unless $err;

	my @files = ();
	foreach ( @alt_files ){
		if ( m#([^/]+)$# ){
			push ( @files, $1 );
		}else{
			push ( @files, $_ );
		}
	}

	my $pkg = { data_cate => CATE_ALTDATA_NOTIFY,
			data => join(',',@files) . ','
		};

	$pkg = $self->_make_pkg ( $pkg );

	my $socket = $self->_connect_ga;;
	$self->_send_pkg ( $socket, $pkg );
	$pkg = $self->_recv_pkg ( $socket );
	close $socket;

	if ( $pkg->{data} eq DATA_SUCC ){
		return 1;
	}elsif ( $pkg->{data} eq DATA_FAIL ){
		return 0;
	}else{ # unknown data
		$self->{zlog}->fatal ( "GA::GAISC::GAISC_get_alt_result: unknown data [" . $pkg->{data} . "] of alt result" );
		return 0;
	}
		
}

sub GAISC_get_log_result
{
	my $self = shift;

	my @log_files = @_;

	my $ftp = $self->_connect_ftp();
	my $err = 1 unless $ftp;

#print "get log before ftp put: " . $self->{GAISC}->{FTPDir} . '/log/' . $self->{GAISC}->{GatewayIdentifier} . '/' . "\n";
	$self->ftp_put_file( $ftp, '/home/ssh/log/'
		, '/' . $self->{GAISC}->{FTPDir} . '/log/' . $self->{GAISC}->{GatewayIdentifier} . '/'
		, @log_files ) unless $err;

	$ftp->quit unless $err;

	my @files = ();
	foreach ( @log_files ){
		if ( m#([^/]+)$# ){
			push ( @files, $1 );
		}else{
			push ( @files, $_ );
		}
	}


	my $pkg = { data_cate => CATE_LOGDATA_NOTIFY,
			data => join(',',@files) . ','
		};

	$pkg = $self->_make_pkg ( $pkg );

	my $socket = $self->_connect_ga;
	$self->_send_pkg ( $socket, $pkg );
	$pkg = $self->_recv_pkg ( $socket );
	close $socket;

	if ( $pkg->{data} eq DATA_SUCC ){
		return 1;
	}elsif ( $pkg->{data} eq DATA_FAIL ){
		return 0;
	}else{ # unknown data
		$self->{zlog}->fatal ( "GA::GAISC::GAISC_get_log_result: unknown data [" . $pkg->{data} . "] of log result" );
		return 0;
	}
	
}

sub GAISC_resp_rule_update
{
	my $self = shift;

	my $socket = shift;
	my $pkg = shift;

	my @rule_files = split ( ',', $pkg->{data} );

	$self->{zlog}->debug( Dumper ( @rule_files ) );

	$self->{zlog}->debug ( "center rule_file: " . join(',',@rule_files) );



	my $ruledir = $self->{define}->{ruledir};

	my $err = 0;

	my $ftp = $self->_connect_ftp();
	$err = 1 unless $ftp;

	$self->{files} = ();
	$self->ftp_get_file( $ftp, '/' . $self->{GAISC}->{FTPDir} . '/rule/', $ruledir, @rule_files ) unless $err;

	$ftp->quit;

	my ($rule_add_modify, $rule_del) = $self->parse_rule_to_filterdb( @{$self->{files}} );

	if ( $self->merge_new_rule ( $rule_add_modify, $rule_del ) ){
		$pkg->{data} = DATA_SUCC;
	}else{
		$pkg->{data} = DATA_FAIL;
	}

	$pkg->{data_cate} = CATE_MAILRULE_RESULT;
	$pkg = $self->_make_pkg( $pkg );

	$self->_send_pkg( $socket, $pkg );

	unlink @{$self->{files}} if ( 'ARRAY' eq ref $self->{files} );
	$self->{files} = ();

	return 1;
}

sub parse_logreq_to_filterdb
{
	my $self = shift;
	my $proto_line = shift;

	my $rule_info = {};

	my @log_reqs = split ( /,/, $proto_line, 8 );

	my $log_req = {	start_time	=> $log_reqs[0] || 0,
			end_time	=> $log_reqs[1] || 0,
			ip		=> $log_reqs[2],
			keyword		=> $log_reqs[3],
			keyword_logic	=> ($log_reqs[4] eq '01')?'AND':'OR',
			size		=> $log_reqs[5],
			size_type	=> $log_reqs[6],
			req_mail_data	=> $log_reqs[7]
		};
			
	# 模糊匹配
	$rule_info->{rule_keyword}->{type} = 0;
	# 全文检索
	$rule_info->{rule_keyword}->{key} = 7;
	$rule_info->{id_type} = 'GAISC';
	$rule_info->{update_time} = $self->{zlog}->get_time_stamp();

	my $val;
	if( $log_req->{size} ){
		my $sizeval = $log_req->{size};
		if ( $sizeval=~/^\d+$/ ){
			my ( $min,$max );
			$min = int($sizeval*0.7);
			$max = int($sizeval*1.3);
			$rule_info->{size}->{sizevalue} = "$min-$max";
		}else{
			$rule_info->{size}->{sizevalue} = $sizeval;
		}

		for ( my $n=0; $n<length($log_req->{size_type}); $n++ ){
			if ( '1' eq substr($log_req->{size_type}, $n, 1) ){
				$rule_info->{size}->{key} = $n+1;
				last;
			}
		}
	}

	$rule_info->{keyword_logic} = $log_req->{keyword_logic};

	# 解码
	$rule_info->{rule_keyword}->{decode} = 1;

	$rule_info->{rule_comment} = $log_req->{req_mail_data};

	if ( length($log_req->{keyword}) ){
		my @keywords = split (/;/, $log_req->{keyword});
		if ( $#keywords > 0 ){
			my $rule_keyword = $rule_info->{rule_keyword};
			delete $rule_info->{rule_keyword};

			foreach my $keyword ( @keywords ){
				my $new_rule_keyword = {};
				foreach my $key ( keys %{$rule_keyword} ){
					$new_rule_keyword->{$key} = $rule_keyword->{$key};
				}
				$new_rule_keyword->{keyword} = $keyword;
				push ( @{$rule_info->{rule_keyword}}, $new_rule_keyword );
			}
		}else{
			$rule_info->{rule_keyword}->{keyword} = $keywords[0];
		}
	}

	#$self->{zlog}->debug ( Dumper($log_req) );
	#$self->{zlog}->debug ( Dumper($rule_info) );

	return ( $rule_info, $log_req->{start_time}, $log_req->{end_time}, $log_req->{ip} );
}


sub parse_rule_to_filterdb
{
	my $self = shift;
	my @rule_files = @_;

	my ( $rule_add_modify, $rule_del ) = ();

	my ($type, $db, $ruleid, $rule_info) = ();
	foreach my $file ( @rule_files ){
		($type, $db) = $self->_file2pkg( $file );
		if ( 'ruleaddmodify' eq lc $type ){
			($ruleid, $rule_info) = $self->_pkg2filter ( $db );
			$rule_add_modify->{$ruleid} = $rule_info;
		}else{
			$rule_del->{$db->{'ruleid'}} = '1';
		}
	}

	( $rule_add_modify, $rule_del );
}


sub _file2pkg
{
	my $self = shift;
	my $file = shift;

	unless ( open ( FD, "<$file" ) ){
		$self->{zlog}->fatal ( "GA::GAISC::_file2pkg open [$file] error!" );
		return undef;
	}

	my $type = lc <FD>;
	chomp $type;

	my $db = {};
	while ( <FD> ){
		chomp;
		if ( /^GAISC\.RUL\.(.+)=(.+)/ ){
			$db->{lc $1} = $2;
		}
	}

	close FD;

	($type,$db);
}

sub _pkg2filter
{
	my $self = shift;
	my $pkg = shift;

	my $keyword_keymap = { 1 => 1
			,2 => 2
			,3 => 3
			,4 => 4
			,5 => 5
			,6 => 6
			,7 => 7
			,8 => 8
			,9 => 8 
			,10 => 4
			,11 => 9 };

	my $keyword_logicmap = { '00' => 'OR'
		, '01' => 'AND' };

	my $action_map = { 1 => 1
			,2 => 6
			,3 => 7
			,4 => 5
			,5 => 5 };

	my $realtime_map = { 1 => 'YES',
				2 => 'NO' };

	my $rule_info = {};
	my $ruleid;

	$rule_info->{rule_keyword}->{type} = 0;
	$rule_info->{id_type} = 'GAISC';
	$rule_info->{update_time} = $self->{zlog}->get_time_stamp();

	my $val;
	while ( ($_,$val) = each ( %{$pkg} ) ){
		#print "$_, $val\n";
		if ( /^ruleid$/ ){
			$ruleid = $val;
		}elsif( /^time$/ ){
			$rule_info->{create_time} = $val;
		}elsif( /^expiretime$/ ){
			$rule_info->{expire_time} = $val;
		}elsif( /^infolength$/ ){
			if ( $val=~/^\d+$/ ){
				my ( $min,$max );
				$min = int($val*0.7);
				$max = int($val*1.3);
				$rule_info->{size}->{sizevalue} = "$min-$max";
			}else{
				$rule_info->{size}->{sizevalue} = $val;
			}
		}elsif( /^infotype$/ ){
			for ( my $n=0; $n<length($val); $n++ ){
				if ( '1' eq substr($val, $n, 1) ){
					$rule_info->{size}->{key} = $n+1;
					last;
				}
			}
		#}elsif( /^keyword$/ ){
			#foreach ( split(/,/,$val) ){
			#	$rule_info->{rule_keyword}->{keyword}
			#}
		}elsif( /^rulekeytype$/ ){
			for ( my $pos=1; $pos<=length($val); $pos++ ){
				if ( '1' eq substr($val,$pos-1,1) ){
					$rule_info->{rule_keyword}->{key} = $keyword_keymap->{$pos};
					if ( 11==$pos ){	# IP match
						$rule_info->{rule_keyword}->{type} = 6;
					}else{
						$rule_info->{rule_keyword}->{type} = 0;
					}
					last;
				}
			}
		}elsif( /^keywordtype$/ ){
			$rule_info->{keyword_logic} = $keyword_logicmap->{$val};
		}elsif( /^decode$/ ){
			$rule_info->{rule_keyword}->{decode} = int($val);
		}elsif( /^rule$/ ){
			if ( 2==length($val) ){
				$rule_info->{rule_action}->{action} = $action_map->{substr($val,0,1)} || 6;
				$rule_info->{realtime_upload} = $realtime_map->{substr($val,1,1)} || 'NO';
				$rule_info->{alarmlevel} = substr($val,1,1) || 0;
			}
		}elsif( /^alertrule$/ ){
			$rule_info->{rule_comment} = $val;
		}
	}

	if ( length($pkg->{keyword}) ){
		my @keywords = split (/,/, $pkg->{keyword});
		if ( $#keywords > 0 ){
			my $rule_keyword = $rule_info->{rule_keyword};
			delete $rule_info->{rule_keyword};

			foreach my $keyword ( @keywords ){
				my $new_rule_keyword = {};
				foreach my $key ( keys %{$rule_keyword} ){
					$new_rule_keyword->{$key} = $rule_keyword->{$key};
				}
				$new_rule_keyword->{keyword} = $keyword;
				push ( @{$rule_info->{rule_keyword}}, $new_rule_keyword );
			}
		}else{
			$rule_info->{rule_keyword}->{keyword} = $keywords[0];
		}
	}else{
		delete $rule_info->{rule_keyword};
	}

	($ruleid, $rule_info);
}

sub get_file_list
{
	my $self = shift;
	my $path = shift || '/home/ssh/log/';
	my $ext = shift || 'log';
	
	opendir ( LOG_DIR, $path ) ;
	my @logfiles = grep { /\.$ext/ && -f "$path/$_" } readdir(LOG_DIR);
	closedir ( LOG_DIR );

	@logfiles;
}

sub GAISC_resp_log_update
{
	my $self = shift;

	my $socket = shift;
	my $pkg = shift;

	my ($rule_info, $start_time, $end_time, $ip) = $self->parse_logreq_to_filterdb( $pkg->{data} );

	use AKA::Mail::Content::Rule;
	my $content_rule = new AKA::Mail::Content::Rule ( $self );
	$content_rule->{GAISC_log_filterdb}->{log_match_rule_id} = $rule_info;

	use AKA::Mail::Content::Parser;
	my $content_parser = new AKA::Mail::Content::Parser ( $content_rule );

	my @emlfiles = $self->get_file_list( '/home/ssh/log/', 'eml' );

	my @log_files = ();

	my $mail_info = {};

	foreach my $emlfilename ( @emlfiles ){
		unless ( $emlfilename =~ /^(\d{14})\-\d+\.eml/ ){
			$self->{zlog}->debug ( "GAISC_resp_log_update: emlfilename [$emlfilename] format err" );
			next;
		}

		if ( $start_time && $end_time && ($1 < $start_time || $1 > $end_time) ){
			$self->{zlog}->debug ( "GAISC_resp_log_update: emlfilename [$emlfilename] time not match[$start_time,$end_time]" );
			next;
		}

		unless ( open( FD, "</home/ssh/log/$emlfilename" ) ){
			$self->{zlog}->fatal ( "GAISC::GAISC_resp_log_update open emlfile [$emlfilename] error $!" );
			next;
		}

		$mail_info = $content_parser->get_mail_info ( \*FD );
		close FD;
		$content_parser->clean();

#print Dumper($mail_info);

		if ( length($ip) && $mail_info->{head}->{content}!~ /$ip/ ) {
			$self->{zlog}->fatal ( "GAISC::GAISC_resp_log_update [$emlfilename] not match ip [$ip]" );
			next;
		}

		# only check if we have rule
#$self->{zlog}->debug( Dumper($rule_info) );
		if ( defined $rule_info->{size}->{sizevalue} 
				|| length($rule_info->{rule_keyword}->{keyword}) 
				|| $rule_info->{attachment} ){
			my $log_match = $content_rule->check_all_rule_backend('GAISC_log_filterdb', $mail_info );
			next unless ( 'log_match_rule_id' eq $log_match );
		}

		$mail_info->{aka}->{rule_info} = $rule_info;
		$mail_info->{aka}->{emlfilename} = "/home/ssh/log/$emlfilename";
		push ( @log_files, $self->make_log($mail_info) );
	}

	$pkg = {	data_cate	=> CATE_LOGRULE_RESULT,
			data		=> DATA_SUCC
		};

	$pkg = $self->_make_pkg( $pkg );
	$self->_send_pkg( $socket, $pkg );


	$self->GAISC_get_log_result( @log_files ) if ( @log_files );
#print Dumper ( @log_files );
	unlink @log_files;

	return 1;
}

sub GAISC_resp_ping
{
	my $self = shift;

	my $socket = shift;
	my $pkg = shift;

	return undef unless $pkg->{data} =~ /([^,]+),([^,]+),([^,]+),([^,]+)/ ;

	$self->_update_config( {	FTPDir => $1,
			FTPPort => $2,
			FTPUser => $3,
			FTPPass => $4
		});

	$pkg = { 	data	=> $self->{GAISC}->{LocalIP} . ',' . $self->{GAISC}->{LocalPort} . ',' ,
			data_cate => CATE_PONG
		};


	$pkg = $self->_make_pkg ( $pkg );
	$self->_send_pkg ( $socket, $pkg );
}

sub _update_config
{
	my $self = shift;

	my $config = shift;
	
        my $C = Config::Tiny->read( $self->{define}->{GAISC_conffile} );
	foreach ( keys %$config ){
		$C->{_}->{$_} = $config->{$_};
	}


	$C->write($self->{define}->{GAISC_conffile}); 
	$self->{GAISC} = $self->get_conf;
}

sub _make_pkg
{
	my $self = shift;

	my $req = shift;
	my $def_req = {	data_id => $self->{GAISC}->{DataIdentifier},
			sys_id => $self->{GAISC}->{SystemIdentifier},
			gw_id => $self->{GAISC}->{GatewayIdentifier},
			timestamp => $self->get_timestamp,
			data_cate => CATE_REQ_LINK,
			data => ''
	};

	$def_req->{$_} = $req->{$_} foreach ( keys %$req );

	return $def_req;
}

sub _send_pkg
{
	my $self = shift;

	my $socket = shift;
	my $pkg = shift;

	unless ( $socket ){
		$self->{zlog}->fatal ( "GA::GAISC::_recv_pkg can't get socket" );
		return undef;
	}

	$socket->print ( $pkg->{data_id} . $pkg->{sys_id} . $pkg->{gw_id}
			. $pkg->{timestamp} . $pkg->{data_cate} . $pkg->{data} . "E\n" );
}

sub _recv_pkg
{
	my $self = shift;

	my $socket = shift;

	unless ( $socket ){
		$self->{zlog}->fatal ( "GA::GAISC::_recv_pkg can't get socket" );
		return undef;
	}
	my $resp = $socket->getline;


	return undef unless $resp =~ /^(.{5})(.{10})(.{10})(.{14})(.{10})(.+)E/ ;

	return {	data_id => $1,
			sys_id => $2, 
			gw_id => $3,
			timestamp => $4,
			data_cate => $5,
			data => $6
		};
	
}

sub _connect_ftp
{
	my $self = shift;

#	print Dumper($self->{GAISC});
	my $ftp = Net::FTP->new( $self->{GAISC}->{ServerIP}, Port=>$self->{GAISC}->{FTPPort}, Debug => 0);

	unless ( $ftp ){
		$self->{zlog}->fatal ( "GA::GAISC::_connect_ftp to IP: [" 
			. $self->{GAISC}->{ServerIP} . "] Port: [" 
			. $self->{GAISC}->{FTPPort} . "] failure" );
		sleep 1;
		return undef;
	}

	unless ( $ftp->login( $self->{GAISC}->{FTPUser},
			$self->{GAISC}->{FTPPass} ) ){
		$self->{zlog}->fatal ( "GA::GAISC::_connect_ftp login user: ["
			. $self->{GAISC}->{FTPUser} . "] pass: ["
			. $self->{GAISC}->{FTPPass} . "] failure!" );
		return undef;
	}
			
	unless ( $ftp->cwd( '/' . $self->{GAISC}->{FTPDir} ) ){
		$self->{zlog}->fatal ( "GA::GAISC::_connect_ftp cwd to path: ["
			. $self->{GAISC}->{FTPDir} . "] failure!" );
	}

	$ftp;
}

sub ftp_put_file
{
	my $self = shift;

	my ($ftp, $srcdir, $dstdir, @files) = @_;

print "path: $srcdir -> $dstdir, files: " . join(',', @files) . "\n";

	unless ( $ftp->cwd( $dstdir ) ){
		$ftp->delete ( $dstdir );
		unless ( $ftp->mkdir ( $dstdir, 1 ) ){
			$self->{zlog}->fatal ( "GA::GAISC::ftp_put_file mkdir [$dstdir] failure!" );
			return undef;
		}
		$ftp->cwd ( $dstdir );
	}

	foreach ( @files ){
		$self->{zlog}->debug( "GA::GAISC::ftp_put_file putting $_" );
		$_ = $srcdir . $_ unless ( m#/# );
		if ( ! $ftp->put($_) ){
			$self->{zlog}->fatal ( "GA::GAISC::ftp_put_file put file [$srcdir / $_] to [$dstdir] fialure!" );
		}
	}
	return 1;
}

sub ftp_get_file
{
	my $self = shift;
	my ($ftp, $remote_dir, $local_dir, @files) = @_;

	if ( ! $ftp->cwd( $remote_dir ) ){
		$self->{zlog}->debug( "GA::GAISC::ftp_get_file: cwd to [$remote_dir] failure!" );
		return undef;
	}

	#chdir $ruledir or 
	#	return $self->{zlog}->fatal ( "GA::GAISC::ftp_get_file lcd to [$ruledir] failure!" );

	foreach ( @files ){
		$self->{zlog}->debug ( "GA::GAISC::ftp_get_file getting $_" );
		if ( ! $ftp->get($_, "$local_dir/$_") ){
			$self->{zlog}->debug( "GA::GAISC::ftp_get_file: get file [$_] to [$local_dir] failure!" );
			next;
		}
		push ( @{$self->{files}}, "$local_dir/$_" );
	}

	return 1;
}


