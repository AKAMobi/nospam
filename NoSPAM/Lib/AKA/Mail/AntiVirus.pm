#
# 北京互联网接警中心邮件过滤器
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-02-10


package AKA::Mail::AntiVirus;

use AKA::Mail;
use AKA::Mail::Log;
use AKA::Mail::Conf;

use IO::Socket;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval );

sub new
{
	my $class = shift;

	my $self = {};

	bless $self, $class;

	my $parent = shift;

	$self->{parent} = $parent;
	$self->{zlog} = $parent->{zlog} || new AKA::Mail::Log;
	$self->{conf} = $parent->{conf} || new AKA::Mail::Conf;

	$self->{define}->{host} = '127.0.0.1';
	$self->{define}->{port} = 3310;
	$self->{define}->{status_file} = '/home/NoSPAM/var/run/clamd.';

	return $self;

}

sub init_socket
{
	my $self = shift;
	my $rescue = shift || 0;

	$self->{clamd} = IO::Socket::INET->new(Proto =>"tcp",
                                Timeout => 10,
                                PeerAddr =>$self->{define}->{host},
                                PeerPort =>$self->{define}->{port}
				 ) ;
#print "socket: " . $self->{clamd} . "\n";
#print "\n";
#print "###########connect: " . $self->{clamd}->connected?'YES':'NO' . "\n";
#print "\n";

	if ( !defined $self->{clamd} || ! $self->{clamd}->connected ){
		$self->restart_clamd();
		if ( $rescue ){
			$self->{zlog}->fatal( "init_socket still can't connect after a restart of clamd" );
			return undef;
		}
		return $self->init_socket ( 1 );
	}

	$self->{clamd}->autoflush(1);
	#select($self->{clamd}); $|=1;
	#select(STDOUT);

	return $self->{clamd};
}


sub catch_virus
{

	my $self = shift;
	my $file = shift;

  	my $start_time=[gettimeofday];

	my $result;

	if ( $self->is_clamd_up() ){
		$result = $self->check_file_socket_tcp( $file );
		#$self->{zlog}->debug ( "catch_virus use clamd" );#, result: [$result]" );
	}else{
		# XXX pass virus for performance problem
		return ( {	result	=> 0,
				desc => '更新中',
				action =>  0,

				enabled	=> 1,
				runned	=> 1,
				runtime	=> int(1000*tv_interval ($start_time, [gettimeofday]))
			});

#		$result = $self->check_file_clamscan( $file );
#		$self->{zlog}->debug ( "catch_virus use clamscan" ); #, result: [$result]" );
	}

	if ( $result =~ m#ERROR$# ){
		$self->{zlog}->fatal ( "AntiVirus return ERROR[$result] for file[$file]" );
		return ( {	result 	=> 0,
				desc 	=> '内部错误',
				action => 0, 

				enabled	=> 1,
				runned	=> 1,
				runtime	=> int(1000*tv_interval ($start_time, [gettimeofday]))
			});
	}

	$result =~ m#^$file: (.+)#;
	# get rid of filename
	$result = $1;

	# get result
	$result =~ m#(OK)|(.+) FOUND#;
	my $is_virus = (defined $1)?0:1;
	my $virus_name = $2 if $is_virus;

	my $action = 0; #(AKA::Mail::ACTION_PASS);

#$self->{zlog}->debug ( "antivirus: action: [" . $action . "]" );
	if ( $is_virus ){
		if ( 'Y' eq $self->{conf}->{config}->{AntiVirusEngine}->{RefuseVirus} ){
			$action = 1; #(AKA::Mail::ACTION_REJECT); # 1、reject：
		}elsif ( 'D' eq $self->{conf}->{config}->{AntiVirusEngine}->{RefuseVirus} ){
			$action = 2; #(AKA::Mail::ACTION_DISCARD); # 2、discard
		}else{ # 'N'
			$action = 6; # (AKA::Mail::ACTION_NULL);
		}
	}else{
		$action = 7; #(AKA::Mail::ACTION_ACCEPT);
	}

	return ( {	result	=> $is_virus,
			desc => $virus_name||'',
			action => $action,
			enabled	=> 1,
			runned	=> 1,
			runtime	=> int(1000*tv_interval ($start_time, [gettimeofday]))
		});

}

sub check_file_clamscan
{
	my $self = shift;

	my $file = shift;

	# get rid of double //
	$file =~ s#//#/#g;

	if ( ! open ( FD, "/usr/bin/clamscan -m --infected --disable-summary --stdout $file|" ) ) {
		$self->{zlog}->fatal ( "check_file_clamscan open failure with file [$file]" );
		return '';
	}
	my $result = <FD>; 
	chomp $result;
	close FD;

	return $result;
}

sub check_file_socket_tcp
{
	my $self = shift;

	my $file = shift;
	my $rescue = shift || 0;

	my $result ; 

	#$self->{zlog}->debug ( "check_file_socket_tcp before init_socket." );
	my $conn = $self->init_socket;
	#$self->{zlog}->debug ( "check_file_socket_tcp after init_socket." );
	unless ( $conn ){
		$self->{zlog}->fatal ( "Mail::AntiVirus::check_file_socket_tcp init_socket failure $!" );
		return undef;
	}

	#print $conn "SESSION\n";

	my ($old_alarm_sig,$old_alarm);

	eval {
		$old_alarm_sig = $SIG{ALRM};
		local $SIG{ALRM} = sub { die "CLAMAV DIE" };
		$old_alarm = alarm 3;
		print $conn "PING\n";
		$result = <$conn>;
		chomp $result;
	};
	my $alarm_status=$@;
	$SIG{ALRM} = $old_alarm_sig || 'IGNORE';
	alarm $old_alarm;
	
	if ($alarm_status and $alarm_status ne "" ) { 
		$self->{zlog}->debug ( "PING timeout" );
		#if ($alarm_status eq "CLAMAV DIE") {
		$self->restart_clamd();
		if ( $rescue ){
			$self->{zlog}->fatal ( "check_file_socket_tcp still can't PING after a restart." );
			return '';
		}
		shutdown ( $conn, 2 );
		close $conn;
		return $self->check_file_socket_tcp ( $file, 1 );
	}

	if ( $result ne 'PONG' ){
		$self->{zlog}->fatal ( "PING return not PONG[$result]" );
		shutdown ( $conn, 2 );
		close $conn;
		return '';
	}

	shutdown ( $conn, 2 );
	close $conn;

	eval {
		$old_alarm_sig = $SIG{ALRM};
		local $SIG{ALRM} = sub { die "CLAMAV DIE" };
		$old_alarm = alarm 10;

		$conn = $self->init_socket;
		print $conn "SCAN $file\n";
		$result = <$conn>; 
		chomp $result;
	};
	$alarm_status=$@;
	$SIG{ALRM} = $old_alarm_sig || 'IGNORE';
	alarm $old_alarm;
	if ($alarm_status and $alarm_status ne "" ) { 
		$self->{zlog}->fatal ( "check_file_socket_tcp SCAN file tcp timeout(10)." );
	}
	
	#print $conn "END\n";
	#<$conn>;
	shutdown ( $conn, 2 );
	close $conn;

	return $result;
}

sub set_clamd_down
{
	my $self = shift;

	$self->{zlog}->debug ( "set_clamd_down" );
	if ( -f $self->{define}->{status_file} . 'OK' ){
		rename  $self->{define}->{status_file} . 'OK', 
			$self->{define}->{status_file} . 'ERR'  ;
	}elsif ( !-f $self->{define}->{status_file} . 'ERR' ){
		open ( FD, ">" . $self->{define}->{status_file} . 'ERR' );
		close ( FD );
	}
	my $time = time;
	utime $time, $time, $self->{define}->{status_file} . 'ERR'  ;

}

sub set_clamd_up
{
	my $self = shift;
	$self->{zlog}->debug ( "set_clamd_up" );

	if ( -f $self->{define}->{status_file} . 'ERR' ){
		rename $self->{define}->{status_file} . 'ERR', 
			$self->{define}->{status_file} . 'OK'  ;
	}elsif ( !-f $self->{define}->{status_file} . 'OK' ){
		open ( FD, ">" . $self->{define}->{status_file} . 'OK' );
		close ( FD );
	}
	my $time = time;
	utime $time, $time, $self->{define}->{status_file} . 'OK'  ;
}

sub is_clamd_up
{
	my $self = shift;
	#$self->{zlog}->debug ( "is_clamd_up" );

	if ( -f $self->{define}->{status_file} . 'OK' ){
		#$self->{zlog}->debug ( "is_clamd_up find OK" );
		return 1;
	}elsif ( -f $self->{define}->{status_file} . 'ERR' ){
	        my $mtime = (stat( $self->{define}->{status_file} . 'ERR' ))[9];
		# 如果存在ERR并且最后修改离现在<10min，则认为daemon down
		if ( time - $mtime < 600 ){
			$self->{zlog}->debug ( "is_clamd_up find ERR" );
			return 0;
		}
		$self->{zlog}->debug ( "is_clamd_up find OLD ERR" );
	}
	# has no OK nor ERR, 
	# 	or long time down.
	# maybe system initial, long time die as need a restart

	my $time = time;
	utime $time, $time, $self->{define}->{status_file} . 'ERR'  ;

	$self->restart_clamd;
	return 1;
}

sub restart_clamd
{
	my $self = shift;
	$self->{zlog}->debug ( "researt_clamd" );

	#return system("killall -9 clamd > /dev/null 2>&1 ; /usr/sbin/clamd >/dev/null 2>&1; sleep 1;");

	$self->set_clamd_down();

	use Fcntl ':flock'; # import LOCK_* constants

	if ( open ( LOCKFD, '>' . $self->{define}->{status_file} . 'lock' )  ){
		if ( flock(LOCKFD,LOCK_EX|LOCK_NB) ){
			system("/etc/init.d/clamd restart > /dev/null 2>&1;");
			sleep 3;
			$self->set_clamd_up();
			flock (LOCKFD,LOCK_UN);
		}else{
			$self->{zlog}->debug ( "researt_clamd: this is another process is restarting..." );
		}
		close ( LOCKFD );
	}

}

1;
