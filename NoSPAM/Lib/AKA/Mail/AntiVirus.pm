#
# 北京互联网接警中心邮件过滤器
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-02-10


package AKA::Mail::AntiVirus;

use AKA::Mail::Log;
use AKA::Mail::Conf;

use IO::Socket;

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

	return $self;

}

sub init_socket
{
	my $self = shift;

	undef $self->{socket};

	$self->{socket} ||= IO::Socket::INET->new(Proto =>"tcp",
                                PeerAddr =>'127.0.0.1',
                                PeerPort =>3311 ) || return undef;

	return $self->{socket};
}


sub catch_virus
{

	my $self = shift;

	my $mail_info = shift;
	if ( 'Y' ne $self->{conf}->{config}->{AntiVirusEngine}->{AntiVirusEngine} ){
		return ( { 	Result => 0,
				Reason => '病毒引擎未启动',
				Action => 0 
			} );
	}

	my $file = $mail_info->{emlfilename};

	#my $result = $self->check_file_socket_tcp( $file );
	my $result = $self->check_file_clamscan( $file );

	if ( $result =~ m#ERROR$# ){
		$self->{zlog}->fatal ( "AntiVirus return ERROR[$result] for file[$file]" );
		return ( {	Result => 0,
				Reason => '病毒引擎内部错误',
				Action => 0 
				});
	}

	$result =~ m#^$file: (.+)#;
	# get rid of filename
	$result = $1;

	# get result
	$result =~ m#(OK)|(.+) FOUND#;
	my $is_virus = (defined $1)?0:1;
	my $virus_name = $2 if $is_virus;


	return ( {	Result	=> $is_virus,
			Reason => $virus_name||'',
			Action =>  ('Y' eq $self->{conf}->{config}->{AntiVirusEngine}->{RefuseVirus})?1:0 
			});

}

sub check_file_clamscan
{
	my $self = shift;

	my $file = shift;

	# get rid of double //
	$file =~ s#//#/#g;

	if ( ! open ( FD, "/usr/bin/clamscan --disable-summary --stdout $file|" ) ) {
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

	# get rid of double //
	$file =~ s#//#/#g;

	my $result ; 

	my $conn = $self->init_socket;

	print $conn "SESSION\n";

	eval {
		$SIG{ALRM} = sub { die "CLAMAV DIE" };
		alarm 2;
		print $conn "PING\n";
		$result = <$conn>;
		chomp $result;



		alarm 0;
	};

	if ( $result ne 'PONG' ){
		$self->{zlog}->fatal ( "PING return not PONG[$result]" );
	}

	print $conn "SCAN $file\nEND\n";
	print $conn $req;
	$result = <$conn>; 
	chomp $result;
	close $conn;

	return $result;
}
1;



