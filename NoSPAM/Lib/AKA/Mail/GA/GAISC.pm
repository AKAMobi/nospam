#!/usr/bin/perl -w

package AKA::Mail::GA::GAISC;

use strict;

use vars qw(@ISA);
use AKA::Mail::GA;
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

# XXX where's 95??
use constant CATE_LOGRULE_NOTIFY	=> '0000000094';
use constant CATE_LOGRULE_RESULT	=> '0000000006';

use constant CATE_PING			=> '0000000095';
use constant CATE_PONG			=> '0000000005';

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


sub start_daemon_process
{
	my $self = shift;

	$self->GAISC_get_ftp_info();
	$self->GAISC_server;
}

sub update_rule
{
	# suppress GA compain
	# GAISC update rule is passiveness
}

sub feed_log
{
	# TODO get all logfile match the given condition.
}

sub feed_alert
{
	# TODO get all logfile match the given condition.
}

sub make_log
{
	my $self = shift;

	# TODO copy file to ssh/log, and return filepathname
}

sub make_alert
{
	my $self = shift;

	# TODO gen alert file, and return filepathname
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

	$self->{zlog}->debug(  Dumper ( $proto_action ) );
	$self->{zlog}->debug ( "got GAISC data_cate: [" . $pkg->{data_cate} . "]" );

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
	close $socket;

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

	my $pkg = { data_cate => CATE_ALTDATA_NOTIFY,
			data => join(',',@alt_files) . ','
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

	my $pkg = { data_cate => CATE_LOGDATA_NOTIFY,
			data => join(',',@log_files) . ','
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
	$self->ftp_get_file( $ftp, '/dzyj/rule/', $ruledir, @rule_files ) unless $err;

	my ($rule_add_modify, $rule_del) = $self->parse_rule_to_filterdb( @{$self->{files}} );

	if ( $self->merge_new_rule ( $rule_add_modify, $rule_del ) ){
		$pkg->{data} = DATA_SUCC;
	}else{
		$pkg->{data} = DATA_FAIL;
	}

	$pkg = { data_cate	=> CATE_MAILRULE_RESULT };
	$pkg = $self->_make_pkg( $pkg );

	$self->_send_pkg( $socket, $pkg );

	unlink @{$self->{files}} if ( 'ARRAY' eq ref $self->{files} );

	return 1;
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
			$rule_del->{$ruleid} = '1';
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
		print "$_, $val\n";
		if ( /^ruleid$/ ){
			$ruleid = $val;
		}elsif( /^time$/ ){
			$rule_info->{create_time} = $val;
		}elsif( /^expiretime$/ ){
			$rule_info->{expire_time} = $val;
		}elsif( /^infolength$/ ){
			$rule_info->{size}->{sizevalue} = $val;
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
			for ( my $n=0; $n<length($val); $n++ ){
				if ( '1' eq substr($val,$n,1) ){
					$rule_info->{rule_keyword}->{key} = $keyword_keymap->{$val};
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
	}

	($ruleid, $rule_info);
}


sub GAISC_resp_log_update
{
	my $self = shift;

	my $socket = shift;
	my $pkg = shift;

	my @log_req = split ( /,/, $pkg->{data}, 8 );

	my @keyword = split(/;/, $log_req[3]);
	my $log_req = {	start_time	=> $log_req[0] || 0,
			end_time	=> $log_req[1] || 0,
			ip		=> $log_req[2],
			keyword		=> \@keyword,
			keyword_logic	=> ($log_req[4] eq '01')?'AND':'OR',
			size		=> $log_req[5],
			size_type	=> $log_req[6],
			req_mail_data	=> $log_req[7]
		};
			

	$self->{zlog}->debug ( Dumper($log_req) );

	$pkg = {	data_cate	=> CATE_LOGRULE_RESULT,
			data		=> DATA_SUCC
		};

	$pkg = $self->_make_pkg( $pkg );
	$self->_send_pkg( $socket, $pkg );

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

	return $C->write($self->{define}->{GAISC_conffile});

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

	$socket->print ( $pkg->{data_id} . $pkg->{sys_id} . $pkg->{gw_id}
			. $pkg->{timestamp} . $pkg->{data_cate} . $pkg->{data} . "E\n" );
}

sub _recv_pkg
{
	my $self = shift;

	my $socket = shift;

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

	my ($ftp, $path, @files) = @_;


	unless ( $ftp->cwd( $path ) ){
		$ftp->delete ( $path );
		unless ( $ftp->mkdir ( $path, 1 ) ){
			$self->{zlog}->fatal ( "GA::GAISC::ftp_put_file mkdir [$path] failure!" );
			return undef;
		}
		$ftp->cwd ( $path );
	}

	foreach ( @files ){
		$self->{zlog}->debug( "GA::GAISC::ftp_put_file putting $_" );
		if ( ! $ftp->put($_) ){
			$self->{zlog}->fatal ( "GA::GAISC::ftp_put_file put file [$_] to [$path] fialure!" );
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

sub test_ftp
{
	my $self = shift;

	my $ftp = $self->_connect_ftp();
	#ftp_put_file( $ftp, ".", "GAISC.conf" );

	$self->ftp_put_file ( $ftp, "xixi/haha/hoho", "data" );

	$ftp->quit;
}

