#
# IP Util
# Company: AKA Information & Technology Co., Ltd.
# Author: Ed Lee
# EMail: zixia@zixia.net
# Date: 2004-03-01


package AKA::IPUtil;

use AKA::Mail::Log;


sub new
{
	my $class = shift;

	my $self = {};

	bless $self, $class;

	my $parent = shift;

	$self->{parent} = $parent;
	$self->{zlog} = $parent->{zlog} || new AKA::Mail::Log; #die "AKA::IPUtil can't get parent zlog";

	return $self;
}

sub ipbitmask2broadcast
{
	my $self = shift;
	my $ip = shift;
	my $bitmask = shift;

	my $ip_long = $self->ip2int($ip);

	# convert from 31 to 01111111111111111111111111111111
	$bitmask = substr( ('0' x $bitmask) . ('1' x 32), 0, 32 );
	$bc_long_mask = $self->bin2dec($bitmask);

	my $broadcast_long = $ip_long | $bc_long_mask;

	return $self->int2ip($broadcast_long);
}



sub bitmask2netmask
{
	my $self = shift;
	my $bitmask = shift;

	# convert from 31 to 11111111111111111111111111111110
	$bitmask = substr( ('1' x $bitmask) . ('0' x 32), 0, 32 );

	$mask1 = $self->bin2dec( substr( $bitmask, 0, 8 ) );
	$mask2 = $self->bin2dec( substr( $bitmask, 8, 8 ) );
	$mask3 = $self->bin2dec( substr( $bitmask, 16, 8 ) );
	$mask4 = $self->bin2dec( substr( $bitmask, 24, 8 ) );

	return "$mask1.$mask2.$mask3.$mask4";
}


sub bin2dec {
	my $self = shift;
	my $bin = shift;

        unpack("N", pack("B32", substr('0' x 32 . $bin, -32)));
}

sub int2ip
{
	my $self = shift;
	my $int = shift;

	my $bin = unpack ( 'B32', pack('N', $int) );

	$ip1 = $self->bin2dec ( substr ( $bin, 0, 8) );
	$ip2 = $self->bin2dec ( substr ( $bin, 8, 8) );
	$ip3 = $self->bin2dec ( substr ( $bin, 16, 8) );
	$ip4 = $self->bin2dec ( substr ( $bin, 24, 8) );

	return "$ip1.$ip2.$ip3.$ip4";
}

sub ip2int{
        my $self = shift;
        my $ip = shift ; 

        return undef unless $ip ;
        
        $ip =~ /0*(\d+)\.0*(\d+)\.0*(\d+)\.0*(\d+)/ ;
        $ip[0] = $1 ; $ip[1] = $2 ; $ip[2] = $3 ; $ip[3] = $4 ;
                
        $ip[0] = 0 if( !$ip[0] ) ; $ip[1] = 0 if( !$ip[1] ) ;
        $ip[2] = 0 if( !$ip[2] ) ; $ip[3] = 0 if( !$ip[3] ) ;

        ($ip[0] << 24) + ($ip[1]<<16) + ($ip[2]<<8) + $ip[3] ;
}               
                

#
#	1 一个具体的IP，如："202.116.12.34"
# 	2 用减号"-"连接两个IP值，表示一个连续的IP段（包括两个断点），如："202.116.22.1-202.116.22.24"
#	3 用斜杠"/"分隔的一个IP值和一个数字。如："202.116.22.0/24"表示202.116.22.*
#
sub is_ip_in_range
{
	my $self = shift;

	my ( $ip, $ip_range ) = @_;

	my ( $ip_long, $start_long, $end_long );

	#$self->{zlog}->debug ( "AKA::IPUtil: check_ip_range ( $ip, $ip_range )" );
	if ( !defined $ip_range ){ 
		$self->{zlog}->fatal ( "AKA::IPUtil: check_ip_range no range found!" );
		return 0;
	}

	if ( $ip_range =~ /^(\d+\.\d+\.\d+\.\d+)$/ ){
		#	1 一个具体的IP，如："202.116.12.34"
		return ( $ip eq $1 );
	}elsif ( $ip_range =~ /(\d+\.\d+\.\d+\.\d+)\-(\d+\.\d+\.\d+\.\d+)/ ){
		# 	2 用减号"-"连接两个IP值，表示一个连续的IP段（包括两个断点），如："202.116.22.1-202.116.22.24"
		my ( $ip_start, $ip_end ) = ( $1, $2 );

		$ip_long = ip2int($self, $ip);
		$start_long = ip2int($self, $ip_start);
		$end_long = ip2int($self, $ip_end);

		return ( ($ip_long >= $start_long) && ($ip_long <= $end_long) );
	}elsif ( $ip_range =~ /(\d+\.\d+\.\d+\.\d+)\/(\d+)/ ){
		#	3 用斜杠"/"分隔的一个IP值和一个数字。如："202.116.22.0/24"表示202.116.22.*
		my $bits = 32-$2;
		my $match_long = ip2int($self, $1);
		$ip_long = ip2int($self, $ip);

		$match_long = $match_long >> $bits;
		$ip_long = $ip_long >> $bits;

		return ( $ip_long == $match_long );
	}

	$self->{zlog}->debug ( "AKA::IPUtil::is_ip_in_range got invalid ip range: [$ip_range]" );
	# got no match!
	return 0;
}
	

1;



