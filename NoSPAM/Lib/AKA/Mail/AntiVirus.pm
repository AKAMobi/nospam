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
                                PeerPort =>3310 ) || return undef;

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
	
	return $self->check_file( $mail_info );
}

sub check_file
{
	my $self = shift;

	my $mail_info = shift;

	my $file = $mail_info->{emlfilename};

	my $conn = $self->init_socket;

	my $req = "SCAN $file\n";
	print $conn $req;
	my $result = <$conn>; 
	chomp $result;
	close $conn;

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
1;



