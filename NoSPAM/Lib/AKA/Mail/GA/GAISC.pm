#!/usr/bin/perl -w

package AKA::Mail::GA::GAISC;

use strict;

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

	$self->{parent} = $parent;
	$self->{conf} = $parent->{conf} || new AKA::Mail::Conf;
	$self->{zlog} = $parent->{zlog} || new AKA::Mail::Log;
	
	$self->{define}->{archivedir} = "/home/vpopmail/domains/localhost.localdomain/archive/Maildir/";

	return $self;
}


my $self = {};
$self->{GAISC} = &get_conf;

#&test_ftp;


my $socket = &_connect_ga;

my $result;
$result  = GAISC_get_alt_result( '200007230945560001.alt' );
print "alt result: $result \n";

close $socket;
$socket = &_connect_ga;
$result = GAISC_get_ftp_info();
print "ftp info: \n" . Dumper ( $result );


close $socket;
$socket = &_connect_ga;
$result  = GAISC_get_log_result( '200007230945560001.log' );
print "log result: $result \n";

GAISC_server();

sub get_conf
{
        my $C = Config::Tiny->read( 'GAISC.conf' );
	return $C->{_};
}

sub _get_action
{

	return {	(CATE_MAILRULE_NOTIFY)	=> \&GAISC_resp_rule_update,
			(CATE_LOGRULE_NOTIFY)	=> \&GAISC_resp_log_update,
			(CATE_PING)		=> \&GAISC_resp_ping
		}
}



sub GAISC_server
{
	my $server = new IO::Socket::INET( LocalAddr => $self->{GAISC}->{LocalIP},
					LocalPort => $self->{GAISC}->{LocalPort},
					Proto => 'tcp',
					Type => SOCK_STREAM,
					ReuseAddr => 1,
					Listen => SOMAXCONN
			) || die "Could not create INET socket: $! $@\n";

	my $client ;

	my $pid;

	use POSIX ":sys_wait_h";

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

	while ( 0==$pid ){

		$client = $server->accept;
		print "I'm the $childnum th child\n";

		if (!$client) {
			# this can happen when interrupted by SIGCHLD on Solaris,
			# perl 5.8.0, and some other platforms with -m.
			if ($! == &Errno::EINTR) {
				next;
			} else {
				sleep 1;
				warn "accept failed: $!\n";
				next;
			}
		}

		$client->autoflush(1);

		my($port, $ip) = sockaddr_in($client->peername);
		my $name = gethostbyaddr($ip, AF_INET);

		$ip = inet_ntoa($ip);
		$name ||= $ip;


		&process_protocol( $client );
		close $client;
	}
}

sub process_protocol
{
	my $socket = shift;

	my $GAISC = $socket->getline;

	print "CLNT: $GAISC";
	chomp $GAISC;

	#GAISC 000000DZYJ 0987654321 20040417212923 0000000095 DZYJ,21,test,test,E
	my $pkg = _parse_GAISC ( $GAISC );

	my $proto_action = _get_action();

print Dumper ( $proto_action );
	print "got GAISC data_cate: [" . $pkg->{data_cate} . "]\n";

	if ( defined $proto_action->{$pkg->{data_cate}} ){
	print "defined cate!\n";
		&{$proto_action->{$pkg->{data_cate}}}($socket, $pkg);
	}else{
		print "unknown GAISC data_cate: [" . $pkg->{data_cate} . "]\n";
	}

}

sub _parse_GAISC
{
	my $GAISC = shift;

	unless ( $GAISC =~ /^(.{5})(.{10})(.{10})(.{14})(.{10})(.+),E/ ){
		print "ERR: $GAISC\n";
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
	strftime "%Y%m%d%H%M%S", localtime;
}

sub _connect_ga
{
        my $socket = IO::Socket::INET->new(Proto =>"tcp",
                                Timeout => 10,
                                PeerAddr =>$self->{GAISC}->{ServerIP}, 
                                PeerPort =>$self->{GAISC}->{ServerPort}
                                 ) ;
	unless ( $socket && $socket->connected ){
		die "connect failure";
	}

	$socket;
}

sub GAISC_get_ftp_info
{

	my $pkg = { data_cate => CATE_REQ_LINK,
			data => $self->{GAISC}->{LocalIP} . ',' . $self->{GAISC}->{LocalPort} . ','
		};

	$pkg = _make_pkg ( $pkg );

	my $socket = _connect_ga;
	_send_pkg ( $socket, $pkg );
	$pkg = _recv_pkg ( $socket );
	close $socket;

	return undef unless $pkg->{data} =~ /([^,]+),([^,]+),([^,]+),([^,]+)/ ;

	_update_config( {	FTPDir => $1,
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
	my @alt_files = @_;


	my $pkg = { data_cate => CATE_ALTDATA_NOTIFY,
			data => join(',',@alt_files) . ','
		};

	$pkg = _make_pkg ( $pkg );

	my $socket = _connect_ga;;
	_send_pkg ( $socket, $pkg );
	$pkg = _recv_pkg ( $socket );
	close $socket;

	if ( $pkg->{data} eq DATA_SUCC ){
		return 1;
	}elsif ( $pkg->{data} eq DATA_FAIL ){
		return 0;
	}else{ # unknown data
		print "unknown data of alt result\n";
		return 0;
	}
		
}

sub GAISC_get_log_result
{
	my @log_files = @_;

	my $pkg = { data_cate => CATE_LOGDATA_NOTIFY,
			data => join(',',@log_files) . ','
		};

	$pkg = _make_pkg ( $pkg );

	my $socket = _connect_ga;
	_send_pkg ( $socket, $pkg );
	$pkg = _recv_pkg ( $socket );
	close $socket;

	if ( $pkg->{data} eq DATA_SUCC ){
		return 1;
	}elsif ( $pkg->{data} eq DATA_FAIL ){
		return 0;
	}else{ # unknown data
		print "unknown data of alt result\n";
		return 0;
	}
	
}

sub GAISC_resp_rule_update
{
	my $socket = shift;
	my $pkg = shift;

	my @rule_files = split ( ',', $pkg->{data} );

print Dumper ( $pkg );
	print "center rule_file: $_\n" foreach @rule_files;

	$pkg = {	data_cate	=> CATE_MAILRULE_RESULT,
			data		=> DATA_SUCC
		};

	$pkg = _make_pkg( $pkg );
	_send_pkg( $socket, $pkg );

	return 1;
}

sub GAISC_resp_log_update
{
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
			

print Dumper($log_req);

	$pkg = {	data_cate	=> CATE_LOGRULE_RESULT,
			data		=> DATA_SUCC
		};

	$pkg = _make_pkg( $pkg );
	_send_pkg( $socket, $pkg );

	return 1;
}

sub GAISC_resp_ping
{
	my $socket = shift;
	my $pkg = shift;

	return undef unless $pkg->{data} =~ /([^,]+),([^,]+),([^,]+),([^,]+)/ ;

	_update_config( {	FTPDir => $1,
			FTPPort => $2,
			FTPUser => $3,
			FTPPass => $4
		});

	$pkg = { 	data	=> $self->{GAISC}->{LocalIP} . ',' . $self->{GAISC}->{LocalPort} . ',' ,
			data_cate => CATE_PONG
		};


	$pkg = _make_pkg ( $pkg );
	_send_pkg ( $socket, $pkg );
}

sub _update_config
{
	my $config = shift;
	
        my $C = Config::Tiny->read( 'GAISC.conf' );

	foreach ( keys %$config ){
		$C->{_}->{$_} = $config->{$_};
	}

	return $C->write('GAISC.conf');

	$self->{GAISC} = &get_conf;
}
sub _make_pkg
{
	my $req = shift;
	my $def_req = {	data_id => $self->{GAISC}->{DataIdentifier},
			sys_id => $self->{GAISC}->{SystemIdentifier},
			gw_id => $self->{GAISC}->{GatewayIdentifier},
			timestamp => &get_timestamp,
			data_cate => CATE_REQ_LINK,
			data => ''
	};

	$def_req->{$_} = $req->{$_} foreach ( keys %$req );

	return $def_req;
}

sub _send_pkg
{
	my $socket = shift;
	my $pkg = shift;

	$socket->print ( $pkg->{data_id} . $pkg->{sys_id} . $pkg->{gw_id}
			. $pkg->{timestamp} . $pkg->{data_cate} . $pkg->{data} . "E\n" );
}

sub _recv_pkg
{
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
	print Dumper($self->{GAISC});
	my $ftp = Net::FTP->new( $self->{GAISC}->{ServerIP}, Port=>$self->{GAISC}->{FTPPort}, Debug => 0);

	unless ( $ftp ){
		die "connect failure";
	}

	$ftp->login( $self->{GAISC}->{FTPUser},
			$self->{GAISC}->{FTPPass}
		);
	$ftp->cwd( '/' . $self->{GAISC}->{FTPDir} );

	$ftp;
}

sub ftp_put_file
{
	my $ftp = shift;
	my ($path, @files) = @_;

	if ( ! $ftp->cwd( $path ) ){
		$ftp->delete ( $path );
		if ( ! $ftp->mkdir ( $path, 1 ) ){
			die "mkdir $path failure!";
		}
		$ftp->cwd ( $path );
	}

	foreach ( @files ){
		print "putting $_\n";
		if ( ! $ftp->put($_) ){
			die "put file [$_] fialure!" ;
		}
	}
	return 1;
}

sub ftp_get_file
{
	my $ftp = shift;
	my ($path, @files) = @_;

	if ( ! $ftp->cwd( $path ) ){
		die "cwd to $path failure!";
	}

	chdir '/tmp/ln';

	foreach ( @files ){
		print "getting $_\n";
		if ( ! $ftp->get($_) ){
			die "put file [$_] fialure!" ;
		}
	}

	return 1;
}

sub test_ftp
{
	my $ftp = _connect_ftp();
	#ftp_put_file( $ftp, ".", "GAISC.conf" );

	ftp_put_file ( $ftp, "xixi/haha/hoho", "data" );

	$ftp->quit;
}

