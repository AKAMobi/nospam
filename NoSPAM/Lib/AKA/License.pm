#
# License Control
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-03-07


package AKA::License;

use AKA::Mail::Log;

use Digest::MD5 qw(md5_base64 md5_hex);
use POSIX qw ( mktime );

sub new
{
	my $class = shift;

	my $self = {};

	bless $self, $class;

	my $parent = shift;

	#$self->{parent} = $parent;
	$self->{zlog} = $parent->{zlog} || new AKA::Mail::Log; #die "AKA::IPUtil can't get parent zlog";

	return $self;
}

sub get_valid_license
{
	my $self = shift;

	my $hd_serialno = shift;

	return md5_hex( 'okboy' . $hd_serialno . 'zixia' . $hd_serialno . '@2004-03-07' );
}

sub get_checksum
{
	my $self = shift;

	my $data = shift;

	my $checksum = md5_base64( 'okboy' . $data . 'zixia' . $data . '@2004-03-07' );
#$self->{zlog}->log ("get sum for [$data], result: $checksum"); 
	return $checksum;
}

sub is_valid_checksum
{
	my $self = shift;

	# 不包括 checksum 那行
	my ($license_content,$license_checksum) = @_;

	my $right_sum = $self->get_checksum($license_content);

	if ( $license_checksum eq $right_sum ){
		return 1
	}
#print "right: $right_sum, this: $license_checksum\n";
#print "for data [$license_content]\n";
	return 0;
}

sub get_prodno
{
	my $self = shift;
	
	my $IDserial = '';
	my $id = '';

	$id = &get_IDE_serial;
	$IDserial .= $id if ( $id );

	$id = &get_SCSI_serial;
	$IDserial .= $id if ( $id );

	$id = &get_MAC_serial;
	$IDserial .= $id if ( $id );

	return md5_hex( 'okboy' . $IDserial . 'zixia' . $IDserial . '@2004-03-07' );
}

sub get_MAC_serial
{
	my $self = shift;

	my $id = '';

	my @lines;

	if ( open ( FD, "/sbin/ip li li|grep ether|" ) ){
		@lines = <FD>;
		foreach ( @lines ){
			if ( /ether (..:..:..:..:..:..)/ ){
				$id .= $1;
			}
		}
	}

	$id =~ s/[:\s\n\r]*//g;

	return $id;
}

sub get_SCSI_serial
{
	my $self = shift;

	my $id = '';

	my @lines;

	if ( open ( FD, "</proc/scsi/aic7xxx/0" ) ){
		@lines = <FD>;
		@lines = grep ( /^0x/, @lines );
	}

	$id = join ( "", @lines );

	$id =~ s/[\s\n\r]*//g;

	return $id;
}

sub get_IDE_serial
{
	my $self = shift;

	my $id=' ' x 512;
	my $ret;

	use Fcntl;
	return undef unless open ( HDAFD, "</dev/hda" ) or open ( HDAFD, "</dev/hdb" ) ;
	ioctl( HDAFD, 0x030d, $id ) or die "can't ioctl\n";
	close ( HDAFD );

	# reference to /usr/include/linux/hdreg.h : struct hd_driveid 
	#@id = (unpack ( "S10 C20", $id ))[10...29];
	#$id = join ( "", @id );

	($id) = (unpack ( "S10H40", $id ))[10...29];

	return $id;
}

sub check_hardware
{
	my $self = shift;
	my $hardware_license = shift;

	$hardware_license = $self->decode($hardware_license);

# 	KEY:VAL;KEY:VAL;
	my $hl = {};
	foreach ( split(/;/,$hardware_license) ){
		$hl->{$1} = $2 if ( /(.+)=(.+)/ );
	}

	
	return (0,'处理器不符合要求') if ( exists $hl->{CPU} && ($self->get_CPU_bogomips > $hl->{CPU})  );

	return (1,'硬件系统正确');
}

sub get_CPU_bogomips
{
	my $self = shift;

	my @cpuinfo;
	if ( open ( FD, "</proc/cpuinfo" ) ){
		@cpuinfo = <FD>;
		close FD;
	}
	
	my @bogomips = grep ( /bogomips/, @cpuinfo );

	if ( $bogomips[0]=~/bogomips\s+:\s+(\d+)/ ){
		return $1;
	}

	$self->{zlog}->fatal ( "License::get_CPU_bogomips failed" );

	return 0;
}

sub encode
{
	my $self = shift;
	my $str = shift;

	$str =~ y/=;,:_\-+0-9A-Za-z/a-m5-9N-Zn-zA-M0-4:_\-+;,=/; 
	return  $str;
}

sub decode
{
	my $self = shift;
	my $str = shift;

	$str =~ y/a-m5-9N-Zn-zA-M0-4:_\-+;,=/=;,:_\-+0-9A-Za-z/;
	return $str;
}

sub check_expiredate($$)
{
	my $self = shift;
	my $expire_date = shift;

	my ($year,$month,$date,$hour,$minute,$second);

	($year,$month,$date) = $expire_date=~/(\d+)\-(\d+)\-(\d+)/;
	($hour,$minute,$second) = $expire_date=~/(\d+):(\d+):(\d+)/ ;

	# 如果License中没有expire_date或者parse失败，则认为未过期
	unless ( $year && $month && $date ){
		$self->{zlog}->debug ( "License::check_expiredate parse err: [$expire_date] [$year-$month-$date]" );
		return ( 1, undef ) ;
	}

#	my $now = strftime "%Y-%m-%d %H:%M:%S", localtime;

	$year -= 1900;
	$month -= 1;
	
#$self->{zlog}->debug ( "$second,$minute,$hour,$date,$month,$year" );
	my $expire_time = POSIX::mktime( $second,$minute,$hour,$date,$month,$year );
	my $now_time = time;

#$self->{zlog}->debug ( "License::check_expiredate now [$now_time] expire_time [$expire_time]" );

	return ( 0, '许可证已经过期！' ) if ( $expire_time < $now_time );

	my $days_left = int(($expire_time-$now_time)/86400);

	return ( 1, "<b><font color='red'>许可证将在$days_left天后过期！</font></b>") if ( $days_left < 30 );

	return ( 1,undef );
}

1;



