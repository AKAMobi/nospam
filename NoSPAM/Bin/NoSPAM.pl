#!/usr/bin/perl -w

use strict;
use POSIX qw(strftime);

use AKA::Mail::Conf;
use AKA::Mail::Log;
use AKA::IPUtil;

my $arp_binary = "/sbin/arp";
my $arping_binary = "/sbin/arping";
my $iptables = "/sbin/iptables";
my $ifconfig = "/sbin/ifconfig";
my $ip_binary = "/sbin/ip";
my $hostname_binary = "/bin/hostname";
my $reboot_binary = "/sbin/reboot";
my $shutdown_binary = "/sbin/shutdown";
my $date_binary = "/bin/date";
my $clock_binary = "/sbin/clock";

(my $prog=$0) =~ s/^.*\///g;
my $action = shift @ARGV;
my @param = @ARGV;


my $conf = new AKA::Mail::Conf;
my $intconf = &get_intconf;
my $licenseconf = &get_licenseconf;
my $zlog = new AKA::Mail::Log;
my $iputil = new AKA::IPUtil;

my $action_map = { 'reset_Network' => [\&reset_Network, ""],
			'get_GW_Mode' => [\&get_GW_Mode, ""], 
			'set_GW_Mode' => [\&set_GW_Mode, ""], 
			'get_Serial' => [\&get_Serial, ""],
			'check_License' => [\&check_License, ""],
			'reset_DateTime' => [\&reset_DateTime, "param1: YYYY-mm-DD HH:MM:SS"],
			'clean_Log' => [\&clean_Log, "cat /dev/null > /var/log/NoSPAM.csv"],
			'reboot' => [\&reboot, ""],
			'shutdown' => [\&shutdown, ""]
		};

#use Data::Dumper;
#print Dumper( $intconf );
#print &get_GW_Mode(), "\n";
#exit 0;

# do the action now!

if ( ! defined $action ){
	&usage;
	exit -1;
}elsif( defined $action_map->{$action}[0] ){
	$zlog->debug("NoSPAM Util:: $action @param");
	my $lock = &get_lock( "/home/NoSPAM/var/run/lock/$action" );
	my $ret = &{$action_map->{$action}[0]};
	&release_lock($lock);
	exit $ret;
}else{
	$zlog->fatal( "NoSPAM System Util unsuport action: $action" );
	exit 0;
}


# if program run to here, must be some error!
exit -1;

#############################

sub usage
{
	print STDERR <<_USAGE_;

$prog <action> [action params ...]
  action could be:
_USAGE_
	foreach ( keys %{$action_map} ){
		print STDERR "    $_ ";
		if ( defined $action_map->{$_}[1] ){
			print STDERR "$action_map->{$_}[1]";
		}
		print STDERR "\n";
	}
	print STDERR "\n";
}

sub get_licenseconf
{
	my $licenseconf;

	my $license_file = $conf->{define}->{licensefile};

	open ( LCFD, "<$license_file" ) or return undef;

	my ( $key,$val );
	while (<LCFD>){
		chomp;
		next if ( /^#/ );
		next if ( /^\s*$/ );
		if ( /^(.+)=(.+)$/ ){
			($key,$val) = ($1,$2);
			$key =~ s/\s+//g;
			$val =~ s/\s+//g;
			$licenseconf->{$key} = $val;
		}
	}
	close LCFD;

	$licenseconf->{ServerGatewaySwitchable} ||= 'N';
	$licenseconf->{ServerGateway} ||= 'Gateway';

	return $licenseconf;
}

sub get_intconf
{
	my $intconf;
	
	my $intconf_file = $conf->{define}->{intconffile};

	open ( ICFD, "<$intconf_file" ) or die "NoSPAM Util can't open internal config file\n";

	my ( $key,$val );
	while (<ICFD>){
		chomp;
		next if ( /^#/ );
		next if ( /^\s*$/ );
		if ( /^(.+)=(.+)$/ ){
			($key,$val) = ($1,$2);
			$key =~ s/\s+//g;
			$val =~ s/\s+//g;
			$intconf->{$key} = $val;
		}
	}
	close ICFD;

	$intconf->{GAViewable} ||= 'Y';
	$intconf->{UserLogUpload} ||= 'N';
	$intconf->{MailGatewayInternalIP} ||= '10.4.3.7';
	$intconf->{MailGatewayInternalMask} ||= 32;

	return $intconf;
}

# Shutdown the eth0 & eth1
sub reset_Network_down_eth
{

	my $ret ;

	$ret = system( $ip_binary, "link", "set", "eth0", "down" );
	return -10 if ( $ret );
	$ret = system( $ip_binary, "link", "set", "eth1", "down" );
	return -11 if ( $ret );


	$ret = system( $ip_binary, "ad", "fl", "dev", "eth0" );
	return -20 if ( $ret );
	$ret = system( $ip_binary, "ad", "fl", "dev", "eth1" );
	return -21 if ( $ret );

	return 0;
}

sub reset_Network_clean_netfilter
{

	my $ret;

	$ret = system( $iptables, '-F', 'INPUT' );
	return -10 if ( $ret );
	
	$ret = system( $iptables, '-F', 'FORWARD' );
	return -11 if ( $ret );
	
	$ret = system( "$iptables -t nat -F PREROUTING" );
	return -12 if ( $ret );
	
	$ret = system( $iptables, '-P', 'INPUT', 'ACCEPT' );
	return -13 if ( $ret );
	
	return 0;
}

sub reset_Network_set_netfilter
{
	my $ret;

	$ret = system( "$iptables -A INPUT -p icmp -j ACCEPT" );
	return -1 if ( $ret );

	$ret = system( "$iptables -A INPUT -s 127.0.0.0/8 -j ACCEPT" );
	return -10 if ( $ret );
	$ret = system( "$iptables -A INPUT -s 10.0.0.0/8 -j ACCEPT" );
	return -11 if ( $ret );
	$ret = system( "$iptables -A INPUT -s 192.168.0.0/16 -j ACCEPT" );
	return -12 if ( $ret );
	$ret = system( "$iptables -A INPUT -s 172.16.0.0/20 -j ACCEPT" );
	return -13 if ( $ret );

	$ret = system( "$iptables -A INPUT -s 202.205.10.10/32 -j ACCEPT" );
	return -20 if ( $ret );
	$ret = system( "$iptables -A INPUT -s 202.112.80.0/23 -j ACCEPT" );
	return -21 if ( $ret );
	$ret = system( "$iptables -A INPUT -s 211.157.100.10/26 -j ACCEPT" );
	return -22 if ( $ret );

	$ret = system( "$iptables -A INPUT -p tcp --dport 25 -j ACCEPT" );
	return -30 if ( $ret );
	$ret = system( "$iptables -A INPUT -p tcp --dport 80 -j ACCEPT" );
	return -31 if ( $ret );
	#$ret = system( $iptables, '-A', 'INPUT', '-p tcp', '--dport 110', '-j ACCEPT' );
	#return -32 if ( $ret );
	$ret = system( "$iptables -A INPUT -p tcp --dport 443 -j ACCEPT" );
	return -33 if ( $ret );


	$ret = system( "$iptables -A INPUT -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT" );
	return -40 if ( $ret );
	$ret = system( "$iptables -A INPUT -p udp -m state --state ESTABLISHED,RELATED -j ACCEPT" );
	return -41 if ( $ret );

	$ret = system( "$iptables -P INPUT DROP" );
	return -50 if ( $ret );

	$ret = system( "$iptables -A FORWARD ". 
		'-s '. $conf->{config}->{MailServerIP} . '/' . $conf->{config}->{MailServerNetMask} . 
		' -j ACCEPT' );
	return -60 if ( $ret );
	$ret = system( "$iptables -A FORWARD " . 
		"-d ". $conf->{config}->{MailServerIP} . '/' . $conf->{config}->{MailServerNetMask} . 
		' -j ACCEPT' );
	return -61 if ( $ret );

	$ret = system( "$iptables -t nat -A PREROUTING -i eth1 -p tcp --dport 25 -j DNAT --to " .
		$intconf->{MailGatewayInternalIP} . ":25" );
	return -70 if ( $ret );

	return 0;
}

sub reset_Network_up_eth
{
	my $mode = shift;

	my $ret;

	#邮件主机名称：NoSPAM.conf::MailServerHostname
	$ret = system( $hostname_binary, $conf->{config}->{MailServerHostname} );
	return -10 if ( $ret );

	if ( 'Server' eq $mode ){
		#服务器IP：NoSPAM.conf::MailGatewayIP
		#服务器网络掩码：NoSPAM.conf::MailServerNetMask
		$ret = system( $ip_binary, "ad", "ad", 
			$conf->{config}->{MailGatewayIP} . "/" . $conf->{config}->{MailServerNetMask} , 
			"dev", "eth1" );
		return -21 if ( $ret );

		$ret = system( $ip_binary, "link", "set", "eth1", "up" );
		return -31 if ( $ret );
	}else{ # 'Gateway'
		#本网关内口IP：NoSPAM.intconf::MailGatewayInternalIP
		$ret = system( $ip_binary, "address", "ad", 
			$intconf->{MailGatewayInternalIP} . "/" . $intconf->{MailGatewayInternalMask} , 
			"dev", "eth0" );
		return -20 if ( $ret );
		$ret = system( $ip_binary, "link", "set", "eth0", "up" );
		return -30 if ( $ret );

		#本网关外口IP：NoSPAM.conf::MailGatewayIP
		$ret = system( $ip_binary, "address", "ad", 
			$conf->{config}->{MailGatewayIP} . "/" . $conf->{config}->{MailServerNetMask} , 
			"dev", "eth1" );
		return -22 if ( $ret );
		$ret = system( $ip_binary, "link", "set", "eth1", "up" );
		return -32 if ( $ret );
	}
	return 0;
}

sub reset_Network_set_arp_backend
{
	my ( $dev, $src, $dst ) = @_;

	my $ret;

	$ret = system ( $arp_binary, "-Ds", $src, $dev, "pub" );
	return -1 if ( $ret );

#	$ret = system ( $arping_binary, " -A -c 1 -I $dev -s $src $dst" );
#	return -2 if ( $ret );
	
	return 0;
}

sub reset_Network_set_arp
{
	my $ret;

	my $MailServerIP = $conf->{config}->{MailServerIP};
	my $MailServerNetMask = $conf->{config}->{MailServerNetMask};

	my $NetB;
	($NetB = $MailServerIP) =~ s/\d+$//;

	my $local_net_ip;
	#first, we arp internal net: eth0
	foreach ( 1 ... 255 ){
		$local_net_ip = $NetB . $_;
		next if ( $local_net_ip eq $MailServerIP );
       		next if ( ! $iputil->is_ip_in_range( $local_net_ip, "$MailServerIP/$MailServerNetMask" ) );

		$ret = &reset_Network_set_arp_backend( 'eth0', $local_net_ip, $MailServerIP );
		return -1 if ( $ret );
	}

	#second, we arp external net: eth1
	$ret = &reset_Network_set_arp_backend( 'eth1', $MailServerIP, $conf->{config}->{MailServerGateway} );
	return -2 if ( $ret );

	return 0;
}

sub reset_Network_set_route
{
	my $ret;
	#出口网关：NoSPAM.conf::MailServerGateway
	$ret = system( $ip_binary, "route", "replace", "default", "via", $conf->{config}->{MailServerGateway}, "dev", "eth1" );
	return -1 if ( $ret );

	#邮件服务器IP：NoSPAM.conf::MailServerIP
	$ret = system( $ip_binary, "route", "add", 
		$conf->{config}->{MailServerIP}.'/32',
		"dev", "eth0" );
	return -2 if ( $ret );

	return 0;
}

sub reset_Network_set_sysctl
{
	my $ret;

	$ret = system ( "echo '1'>/proc/sys/net/ipv4/ip_nonlocal_bind" );
	return -1 if ( $ret );

	$ret = system ( "echo '1'>/proc/sys/net/ipv4/ip_forward" );
	return -2 if ( $ret );

	return 0;
}

sub reset_Network_update_hostname
{
	my $mode = shift;
}

sub reset_Network_update_smtproutes
{
	my $mode = shift;
}

sub get_lock
{
	my $filename = shift;

	if ( !open( LOCKFD, ">$filename.lock" ) ){
		return 0;
	}

	use Fcntl ':flock'; # import LOCK_* constants

    	if ( !flock(LOCKFD,LOCK_EX) ){
		return 0;
	}

	return \*LOCKFD;
}

sub release_lock
{
	my $lockfd = shift;
	flock($lockfd,LOCK_UN);
}

#
#
#
########################################
#
# Action Functions
#
########################################
sub reset_Network
{
	$zlog->debug("NoSPAM Util::reset_Network ");

	# Check License;
	use AKA::License;
	my $AL = new AKA::License;
	if ( ! $AL->check_license_file ){
		return 250;
	}

	my $mode = &get_GW_Mode;

	$mode = 'Gateway' if ( 'Server' ne $mode );


	# clean network settings, arp & route should disapear after down_eth
	#&reset_Network_clean_arp;
	#&reset_Network_clean_route;
	&reset_Network_down_eth;
	&reset_Network_clean_netfilter;


	# Start up network settings.
	if ( 	&reset_Network_set_sysctl ||
			&reset_Network_up_eth($mode) ||
			&reset_Network_set_arp($mode) ||
			&reset_Network_set_route($mode) ||
			&reset_Network_set_netfilter($mode) ){
		$zlog->fatal( "NoSPAM Util::reset_Network set network params failure!" );
		return -1;
	}

	if ( &reset_Network_update_hostname($mode) ||
			&reset_Network_update_smtproutes($mode) ){
		$zlog->fatal( "NoSPAM Util::reset_Network update hosts & smtproute file failure!" );
		return -2;
	}

	return 0;
}

sub get_GW_Mode
{
	$zlog->debug("NoSPAM Util::get_GW_Mode ");

	if ( 'Y' eq uc $licenseconf->{'ServerGatewaySwitchable'} ){
		return $conf->{config}->{'ServerGateway'};
	}else{
		return $licenseconf->{'ServerGateway'} || 'Gateway';
	}
}


sub set_GW_Mode
{
	
	$zlog->debug("NoSPAM Util::set_GW_Mode ");
	
	# need reboot.
	return 0;
}

sub get_Serial
{
	
	$zlog->debug("NoSPAM Util::get_Serial ");
	my $AL = new AKA::License;
	print $AL->get_prodno, "\n";
	return 0;
}

sub check_License
{
	$zlog->debug("NoSPAM Util::check_License ");
	use AKA::License;

	my $AL = new AKA::License;

	if ( $AL->check_license_file ){
		# VALID license!
		return 0;
	}
	# INVALID license!
	return -1;
}

sub reset_DateTime
{
	$zlog->debug("NoSPAM Util::reset_DateTime $param[0] $param[1]");

	if ( system("$date_binary -s '$param[0] $param[1]'") ){
		return -1;
	}
	if ( system("$clock_binary -w") ){
		return -2;;
	}
	return 0;
}

sub reboot
{
	$zlog->debug("NoSPAM Util::reboot");
	return system ( "$reboot_binary" );
}

sub shutdown
{
	$zlog->debug("NoSPAM Util::shutdown");
	return system ( "$shutdown_binary now" );
}

sub clean_Log
{
	return `cat /dev/null > /var/log/NoSPAM.csv`;
}

